import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:collection/collection.dart';

import '../../../data/services/local_audio_proxy_server.dart';
import '../../../data/services/media_cache_service.dart';
import '../../../domain/models/media_quality.dart';
import '../../../domain/models/queue_section.dart';
import '../../../domain/models/queue_track.dart';
import '../../../domain/repositories/queue_repository.dart';
import 'playback_engine.dart';

/// Dedicated controller for playback queue management.
///
/// **Responsibilities:**
/// - `_resolvingItemCount` state to suppress intermediate syncs during batch operations
/// - All queue mutations (add, remove, move, clear, purge)
/// - Persistence and synchronization with the `queue` stream and database
/// - Helpers for tagging (section, queueId) and MediaItem ↔ Media conversion
///
/// **Does NOT handle:**
/// - Operations that require playback (setQueue, playNow, skipToQueueItem)
/// - Restore logic, URL resolution, error handling
/// - Volume, crossfade, cast, Android Auto
///
/// This separation of concerns reduces SonoraAudioHandler complexity and
/// centralizes queue logic in one place, eliminating duplication and race
/// conditions.
class QueueController {
  final PlaybackEngine _engine;
  final QueueRepository _queueRepo;
  final List<MediaItem> Function() _getQueue;
  final AudioServiceShuffleMode Function() _getShuffleMode;
  final AudioServiceRepeatMode Function() _getRepeatMode;
  final void Function(List<MediaItem>) _updateQueueStream;
  final LocalAudioProxyServer? _proxyServer;

  /// Current stream audio quality preference (updated from settings).
  MediaQuality streamAudioQuality;

  /// Invoked when the last nested [beginResolving] is matched by
  /// [endResolving]. Used to re-sync playback after URL resolve / retry.
  void Function()? onResolvingIdle;

  int _queueIdCounter = 0;
  int _resolvingItemCount = 0;

  /// FIFO lock so concurrent [runBatch]/[addToQueue] callers cannot interleave
  /// `_engine.add` awaits (which previously mixed albums added in parallel).
  Future<void>? _mutationLock;

  static const String _kSectionKey = 'section';

  QueueController({
    required PlaybackEngine engine,
    required QueueRepository queueRepo,
    required List<MediaItem> Function() getQueue,
    required AudioServiceShuffleMode Function() getShuffleMode,
    required AudioServiceRepeatMode Function() getRepeatMode,
    required void Function(List<MediaItem>) updateQueueStream,
    LocalAudioProxyServer? proxyServer,
    this.streamAudioQuality = MediaQuality.high,
    this.onResolvingIdle,
  }) : _engine = engine,
       _queueRepo = queueRepo,
       _getQueue = getQueue,
       _getShuffleMode = getShuffleMode,
       _getRepeatMode = getRepeatMode,
       _updateQueueStream = updateQueueStream,
       _proxyServer = proxyServer;

  /// HTTP URL a Chromecast on the LAN can fetch (phone proxy, not loopback).
  Future<String?> lanCastUrlFor(QueueTrack track) async {
    if (track.videoId.isEmpty) return null;
    return _proxyServer?.getCastStreamUrlForVideo(
      track.videoId,
      audioQuality: streamAudioQuality,
      preferVideo: prefersVideo(track),
    );
  }

  /// Syncs stream-related prefs from settings without restarting playback.
  void updateStreamPrefs({MediaQuality? streamAudioQuality}) {
    if (streamAudioQuality != null) {
      this.streamAudioQuality = streamAudioQuality;
    }
  }

  // ── Resolving state ────────────────────────────────────────────────────────

  /// True if we're executing a batch operation on the queue (e.g. addAllToQueue).
  /// When true, listeners on `_engine.playlistStream` must suppress
  /// intermediate syncs to avoid race conditions.
  bool get isResolvingItem => _resolvingItemCount > 0;

  /// Increments the in-progress operation counter.
  /// Call before a batch queue operation.
  void beginResolving() {
    _resolvingItemCount++;
  }

  /// Decrements the in-progress operation counter.
  /// Call after a batch queue operation (in the finally block).
  void endResolving() {
    _resolvingItemCount--;
    if (_resolvingItemCount < 0) _resolvingItemCount = 0;
    if (_resolvingItemCount == 0) {
      onResolvingIdle?.call();
    }
  }

  /// Whether [track] should play as video (muxed proxy with `v=1`).
  /// Video playback has been removed; streams are always audio-only.
  bool prefersVideo(QueueTrack track) => false;

  /// Runs [action] exclusively (FIFO) so overlapping callers never interleave
  /// playlist mutations. Used by batch adds, single adds, replaceAt, and
  /// playNow/setQueue (via the audio handler) so Play All + Add to Queue
  /// cannot race with look-ahead URL swaps.
  Future<T> runExclusive<T>(Future<T> Function() action) async {
    final previous = _mutationLock;
    final completer = Completer<void>();
    _mutationLock = completer.future;
    if (previous != null) {
      try {
        await previous;
      } catch (_) {}
    }
    try {
      return await action();
    } finally {
      completer.complete();
      if (identical(_mutationLock, completer.future)) {
        _mutationLock = null;
      }
    }
  }

  /// Runs [action] under [beginResolving]/[endResolving], then syncs the queue
  /// stream. [onSettled] is invoked when no nested batch remains (same guard
  /// the call sites previously used for `_updatePlaybackState`).
  ///
  /// Batches are serialized via [runExclusive] so concurrent `addAllToQueue`
  /// calls append albums as contiguous blocks in call order.
  Future<void> runBatch(
    Future<void> Function() action, {
    required bool isStopping,
    void Function()? onSettled,
  }) async {
    await runExclusive(() async {
      beginResolving();
      try {
        await action();
      } finally {
        endResolving();
        syncQueue(isStopping: isStopping);
        if (!isResolvingItem) {
          onSettled?.call();
        }
      }
    });
  }

  /// Like [replaceAt] but must already be running inside [runExclusive] /
  /// [runBatch]. Calling the locked [replaceAt] from a batch deadlocks.
  Future<int> replaceAtUnlocked(
    int index,
    EngineMedia media, {
    String? expectedVideoId,
  }) => _replaceAtUnlocked(index, media, expectedVideoId: expectedVideoId);

  /// Index of the first Up Next item, or null if none.
  int? get upNextStartIndex {
    final medias = _engine.state.playlist.medias;
    for (var i = 0; i < medias.length; i++) {
      final it = medias[i].mediaItem;
      if (it != null && isUpNext(it)) return i;
    }
    return null;
  }

  /// Replaces the media at [index] while preserving playlist length/order
  /// via [PlaybackEngine.replace]. Serialized with other mutations.
  ///
  /// When [expectedVideoId] is set, re-locates that track if [index] no longer
  /// points at it (concurrent inserts can shift indices between resolve and
  /// swap). Returns the index written, or -1 if the target was not found.
  ///
  /// Must not be called from inside [runExclusive] / [runBatch] — use
  /// [replaceAtUnlocked] instead to avoid deadlock.
  Future<int> replaceAt(
    int index,
    EngineMedia media, {
    String? expectedVideoId,
  }) async {
    return runExclusive(
      () => _replaceAtUnlocked(index, media, expectedVideoId: expectedVideoId),
    );
  }

  Future<int> _replaceAtUnlocked(
    int index,
    EngineMedia media, {
    String? expectedVideoId,
  }) async {
    var target = index;
    if (expectedVideoId != null) {
      final atTarget = _videoIdAt(target);
      if (atTarget != expectedVideoId) {
        target = _indexOfVideoId(expectedVideoId);
        if (target < 0) return -1;
      }
    }
    final len = _engine.state.playlist.medias.length;
    if (target < 0 || target >= len) return -1;

    await _engine.replace(target, media);
    return target;
  }

  String? _videoIdAt(int index) {
    final it = _engine.state.playlist.mediaItemAt(index);
    if (it == null) return null;
    return QueueTrack.fromMediaItem(it).videoId;
  }

  int _indexOfVideoId(String videoId) {
    final medias = _engine.state.playlist.medias;
    for (var i = 0; i < medias.length; i++) {
      final it = medias[i].mediaItem;
      if (it != null && QueueTrack.fromMediaItem(it).videoId == videoId) {
        return i;
      }
    }
    return -1;
  }

  // ── Queue getters ──────────────────────────────────────────────────────────

  List<MediaItem> get _currentQueue =>
      _engine.state.playlist.medias.map((e) => e.mediaItem).nonNulls.toList();

  /// Public read-only view of the current playlist.
  List<MediaItem> get currentQueue => _currentQueue;

  /// User-queue portion (items not tagged as upnext).
  List<MediaItem> get userQueue =>
      _currentQueue.where((it) => !isUpNext(it)).toList();

  /// Autoplay "Up Next" portion.
  List<MediaItem> get upNextQueue => _currentQueue.where(isUpNext).toList();

  // ── Queue section helpers ──────────────────────────────────────────────────

  static QueueSection sectionOf(MediaItem item) {
    return QueueSection.fromTag(item.extras?[_kSectionKey] as String?);
  }

  static bool isUpNext(MediaItem item) =>
      sectionOf(item) == QueueSection.upnext;

  static MediaItem tagSection(MediaItem item, QueueSection section) {
    if (sectionOf(item) == section) return item;
    final extras = Map<String, dynamic>.from(item.extras ?? {});
    extras[_kSectionKey] = section.tag;
    return item.copyWith(extras: extras);
  }

  static MediaItem tagUser(MediaItem item) =>
      tagSection(item, QueueSection.user);

  static MediaItem tagUpNext(MediaItem item) =>
      tagSection(item, QueueSection.upnext);

  // ── QueueId management ─────────────────────────────────────────────────────

  MediaItem ensureQueueId(MediaItem item, [Set<String>? seenIds]) {
    final existingId = item.extras?['queueId'] as String?;
    final isAlreadyInQueue =
        existingId != null &&
        _currentQueue.any((e) => e.extras?['queueId'] == existingId);
    final isDuplicateInBatch =
        existingId != null && seenIds != null && seenIds.contains(existingId);

    if (existingId != null && !isAlreadyInQueue && !isDuplicateInBatch) {
      seenIds?.add(existingId);
      return item;
    }
    final extras = Map<String, dynamic>.from(item.extras ?? {});
    final newId =
        '${item.id}_${DateTime.now().microsecondsSinceEpoch}_${_queueIdCounter++}';
    extras['queueId'] = newId;
    seenIds?.add(newId);
    return item.copyWith(extras: extras);
  }

  // ── Media conversion ───────────────────────────────────────────────────────

  /// Converts a MediaItem to an [EngineMedia] for the playback engine.
  /// Assigns queueId if missing and tags as user section.
  ///
  /// Local `file://` URLs (library downloads and media-cache files) bypass
  /// the proxy so offline playback works. Cast still uses [MediaItem] extras,
  /// not the engine source.
  EngineMedia toMedia(MediaItem item) {
    final tagged = tagUser(ensureQueueId(item));
    final track = QueueTrack.fromMediaItem(tagged);
    final preferVideo = prefersVideo(track);
    final isCache = MediaCacheService.isMediaCacheUri(track.url);
    final useLocal =
        track.isLocalFile &&
        (!isCache ||
            MediaCacheService.isCacheCompatibleWithPreferVideo(
              track.url,
              preferVideo,
            ));
    if (useLocal) {
      return EngineMedia(uri: track.url!, mediaItem: tagged);
    }
    if (_proxyServer != null &&
        _proxyServer.isRunning &&
        track.videoId.isNotEmpty) {
      final proxyUrl = _proxyServer.getStreamUrlForVideo(
        track.videoId,
        audioQuality: streamAudioQuality,
        preferVideo: preferVideo,
      );
      return EngineMedia(uri: proxyUrl, mediaItem: tagged);
    }
    if (track.hasUrl) {
      return EngineMedia(uri: track.url!, mediaItem: tagged);
    }
    final dummy = '$kPlaceholderAudioUriPrefix${track.videoId}.wav';
    return EngineMedia(uri: dummy, mediaItem: tagged);
  }

  // ── Queue mutations ────────────────────────────────────────────────────────

  /// Inserts [item] immediately after the current track.
  Future<void> playNext(MediaItem item) async {
    final ci = _engine.state.playlist.index;
    final insertAt = (ci + 1).clamp(0, _engine.state.playlist.medias.length);
    final media = toMedia(item);
    await _engine.add(media);
    await _engine.move(_engine.state.playlist.medias.length - 1, insertAt);
  }

  /// Adds a single item at the end of the user queue (before Up Next).
  Future<void> addToQueue(MediaItem item) async {
    await runExclusive(() => _appendUserItem(item));
  }

  /// Adds all [items] at the end of the user queue (before Up Next), preserving
  /// call order. Must be invoked under [runBatch]/[runExclusive].
  Future<void> addAllToQueue(List<MediaItem> items) async {
    if (items.isEmpty) return;
    var insertAt = upNextStartIndex;
    for (final item in items) {
      await _engine.add(toMedia(item));
      if (insertAt != null) {
        await _engine.move(_engine.state.playlist.medias.length - 1, insertAt);
        insertAt++;
      }
    }
  }

  /// Appends a user-tagged item before the Up Next boundary (or at end).
  Future<void> _appendUserItem(MediaItem item) async {
    final insertAt = upNextStartIndex;
    await _engine.add(toMedia(item));
    if (insertAt != null) {
      await _engine.move(_engine.state.playlist.medias.length - 1, insertAt);
    }
  }

  /// Appends [items] to the playlist tagging each as part of the autoplay
  /// "Up Next" section.
  Future<void> appendUpNext(List<MediaItem> items) async {
    if (items.isEmpty) return;
    for (final item in items) {
      await _engine.add(toMedia(tagUpNext(item)));
    }
  }

  /// Removes the item at [index].
  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _engine.state.playlist.medias.length) return;
    await _engine.remove(index);
  }

  /// Moves the item from [oldIndex] to [newIndex].
  Future<void> move(int oldIndex, int newIndex) async {
    final len = _engine.state.playlist.medias.length;
    if (oldIndex < 0 || oldIndex >= len) return;
    if (newIndex < 0 || newIndex >= len) return;
    if (oldIndex == newIndex) return;

    // Capture the up-next boundary BEFORE the move
    int? boundary;
    for (int i = 0; i < len; i++) {
      final it = _engine.state.playlist.medias[i].mediaItem;
      if (it != null && isUpNext(it)) {
        boundary = i;
        break;
      }
    }

    await _engine.move(oldIndex, newIndex);
    await _retagMovedItem(newIndex, boundary);
  }

  /// Re-tags the item now sitting at [newIndex] based on the up-next
  /// [boundary] captured before the move.
  Future<void> _retagMovedItem(int newIndex, int? boundary) async {
    final playlist = _engine.state.playlist;
    if (newIndex < 0 || newIndex >= playlist.medias.length) return;
    if (newIndex == playlist.index) return;

    final media = playlist.medias[newIndex];
    final item = media.mediaItem;
    if (item == null) return;

    final target =
        (boundary == null || newIndex < boundary)
            ? QueueSection.user
            : QueueSection.upnext;
    if (sectionOf(item) == target) return;

    final retagged = tagSection(item, target);
    final newMedia = media.copyWith(mediaItem: retagged);
    await replaceAtUnlocked(newIndex, newMedia);
  }

  /// Clears the entire queue.
  Future<void> clear() async {
    await _engine.stop();
    await _engine.open(const [], play: false);
  }

  /// Removes every user-queue track, preserving the autoplay "Up Next" section.
  Future<void> purgeUserQueue() async {
    final medias = _engine.state.playlist.medias;
    final currentIndex = _engine.state.playlist.index;

    for (int i = medias.length - 1; i >= 0; i--) {
      if (i == currentIndex) continue;
      final item = medias[i].mediaItem;
      if (item != null && !isUpNext(item)) {
        await _engine.remove(i);
      }
    }
  }

  /// Removes every item currently tagged as upnext, leaving the user queue
  /// untouched.
  Future<void> purgeUpNext() async {
    final medias = _engine.state.playlist.medias;
    final currentIndex = _engine.state.playlist.index;

    for (int i = medias.length - 1; i >= 0; i--) {
      if (i == currentIndex) continue;
      final item = medias[i].mediaItem;
      if (item != null && isUpNext(item)) {
        await _engine.remove(i);
      }
    }
  }

  // ── Synchronization and persistence ────────────────────────────────────────

  /// Synchronizes the queue stream with the current playlist and persists to disk.
  ///
  /// Call after every queue mutation (add/remove/move) to keep the stream
  /// exposed to the UI and the database in sync.
  void syncQueue({bool isStopping = false}) {
    final playlist = _engine.state.playlist;
    final items = playlist.medias.map((e) => e.mediaItem).nonNulls.toList();

    final newIds =
        items.map((e) => e.extras?['queueId'] as String? ?? e.id).toList();
    final currentIds =
        _getQueue()
            .map((e) => e.extras?['queueId'] as String? ?? e.id)
            .toList();
    final queueStructureChanged =
        newIds.length != currentIds.length ||
        !const ListEquality().equals(newIds, currentIds);

    // The engine may emit an empty playlist while `open` is swapping in
    // a new list. Publishing that transient [] would wipe the audio_service
    // queue stream (empty full-player UI) and persist an empty DB snapshot.
    if (items.isEmpty && currentIds.isNotEmpty && !isStopping) {
      return;
    }

    if (queueStructureChanged) {
      _updateQueueStream(items);
      if (!isStopping) {
        _queueRepo.persistQueue(
          items,
          currentIndex: playlist.index,
          shuffleMode: _getShuffleMode(),
          repeatMode: _getRepeatMode(),
        );
      }
    }
  }

  /// Persists the current queue to disk.
  Future<void> persistQueue({
    required AudioServiceShuffleMode shuffleMode,
    required AudioServiceRepeatMode repeatMode,
  }) async {
    await _queueRepo.persistQueue(
      _currentQueue,
      currentIndex: _engine.state.playlist.index,
      shuffleMode: shuffleMode,
      repeatMode: repeatMode,
    );
  }

  /// Prepares a list of items for playlist opening.
  ///
  /// Assigns unique queueIds and converts to engine media objects.
  /// Returns (itemsWithKeys, medias).
  (List<MediaItem>, List<EngineMedia>) preparePlaylist(
    List<MediaItem> items, {
    int initialIndex = 0,
  }) {
    final seenIds = <String>{};
    final itemsWithKeys =
        items.map((item) => ensureQueueId(item, seenIds)).toList();
    final medias = itemsWithKeys.map(toMedia).toList();
    return (itemsWithKeys, medias);
  }
}

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:collection/collection.dart';
import 'package:media_kit/media_kit.dart';

import '../../../data/services/local_audio_proxy_server.dart';
import '../../../domain/models/queue_section.dart';
import '../../../domain/models/queue_track.dart';
import '../../../domain/repositories/queue_repository.dart';

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
  final Player _player;
  final QueueRepository _queueRepo;
  final List<MediaItem> Function() _getQueue;
  final AudioServiceShuffleMode Function() _getShuffleMode;
  final AudioServiceRepeatMode Function() _getRepeatMode;
  final void Function(List<MediaItem>) _updateQueueStream;
  final LocalAudioProxyServer? _proxyServer;

  int _queueIdCounter = 0;
  int _resolvingItemCount = 0;
  /// FIFO lock so concurrent [runBatch]/[addToQueue] callers cannot interleave
  /// `_player.add` awaits (which previously mixed albums added in parallel).
  Future<void>? _mutationLock;

  static const String _kSectionKey = 'section';

  QueueController({
    required Player player,
    required QueueRepository queueRepo,
    required List<MediaItem> Function() getQueue,
    required AudioServiceShuffleMode Function() getShuffleMode,
    required AudioServiceRepeatMode Function() getRepeatMode,
    required void Function(List<MediaItem>) updateQueueStream,
    LocalAudioProxyServer? proxyServer,
  }) : _player = player,
       _queueRepo = queueRepo,
       _getQueue = getQueue,
       _getShuffleMode = getShuffleMode,
       _getRepeatMode = getRepeatMode,
       _updateQueueStream = updateQueueStream,
       _proxyServer = proxyServer;

  // ── Resolving state ────────────────────────────────────────────────────────

  /// True if we're executing a batch operation on the queue (e.g. addAllToQueue).
  /// When true, listeners on `_player.stream.playlist` must suppress
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
  }

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
    Media media, {
    String? expectedVideoId,
  }) =>
      _replaceAtUnlocked(
        index,
        media,
        expectedVideoId: expectedVideoId,
      );

  /// Index of the first Up Next item, or null if none.
  int? get upNextStartIndex {
    final medias = _player.state.playlist.medias;
    for (var i = 0; i < medias.length; i++) {
      final it = medias[i].extras?['mediaItem'] as MediaItem?;
      if (it != null && isUpNext(it)) return i;
    }
    return null;
  }

  /// Replaces the media at [index] while preserving playlist length/order
  /// (remove → add → move-last-to-index). Serialized with other mutations.
  ///
  /// When [expectedVideoId] is set, re-locates that track if [index] no longer
  /// points at it (concurrent inserts can shift indices between resolve and
  /// swap). Returns the index written, or -1 if the target was not found.
  ///
  /// Must not be called from inside [runExclusive] / [runBatch] — use
  /// [replaceAtUnlocked] instead to avoid deadlock.
  Future<int> replaceAt(
    int index,
    Media media, {
    String? expectedVideoId,
  }) async {
    return runExclusive(
      () => _replaceAtUnlocked(
        index,
        media,
        expectedVideoId: expectedVideoId,
      ),
    );
  }

  Future<int> _replaceAtUnlocked(
    int index,
    Media media, {
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
    final len = _player.state.playlist.medias.length;
    if (target < 0 || target >= len) return -1;

    await _player.remove(target);
    await _player.add(media);
    await _player.move(_player.state.playlist.medias.length - 1, target);
    return target;
  }

  String? _videoIdAt(int index) {
    final medias = _player.state.playlist.medias;
    if (index < 0 || index >= medias.length) return null;
    final it = medias[index].extras?['mediaItem'] as MediaItem?;
    if (it == null) return null;
    return QueueTrack.fromMediaItem(it).videoId;
  }

  int _indexOfVideoId(String videoId) {
    final medias = _player.state.playlist.medias;
    for (var i = 0; i < medias.length; i++) {
      final it = medias[i].extras?['mediaItem'] as MediaItem?;
      if (it != null && QueueTrack.fromMediaItem(it).videoId == videoId) {
        return i;
      }
    }
    return -1;
  }

  // ── Queue getters ──────────────────────────────────────────────────────────

  List<MediaItem> get _currentQueue =>
      _player.state.playlist.medias
          .map((e) => e.extras?['mediaItem'] as MediaItem?)
          .nonNulls
          .toList();

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

  /// Converts a MediaItem to a Media object for media_kit.
  /// Assigns queueId if missing and tags as user section.
  Media toMedia(MediaItem item) {
    final tagged = tagUser(ensureQueueId(item));
    final track = QueueTrack.fromMediaItem(tagged);
    if (_proxyServer != null &&
        _proxyServer.isRunning &&
        track.videoId.isNotEmpty) {
      final proxyUrl = _proxyServer.getStreamUrlForVideo(track.videoId);
      return Media(proxyUrl, extras: {'mediaItem': tagged});
    }
    if (track.hasUrl) {
      return Media(track.url!, extras: {'mediaItem': tagged});
    }
    final dummy = 'http://localhost/dummy_${track.videoId}.wav';
    return Media(dummy, extras: {'mediaItem': tagged});
  }

  // ── Queue mutations ────────────────────────────────────────────────────────

  /// Inserts [item] immediately after the current track.
  Future<void> playNext(MediaItem item) async {
    final ci = _player.state.playlist.index;
    final insertAt = (ci + 1).clamp(0, _player.state.playlist.medias.length);
    final media = toMedia(item);
    await _player.add(media);
    await _player.move(_player.state.playlist.medias.length - 1, insertAt);
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
      await _player.add(toMedia(item));
      if (insertAt != null) {
        await _player.move(_player.state.playlist.medias.length - 1, insertAt);
        insertAt++;
      }
    }
  }

  /// Appends a user-tagged item before the Up Next boundary (or at end).
  Future<void> _appendUserItem(MediaItem item) async {
    final insertAt = upNextStartIndex;
    await _player.add(toMedia(item));
    if (insertAt != null) {
      await _player.move(_player.state.playlist.medias.length - 1, insertAt);
    }
  }

  /// Appends [items] to the playlist tagging each as part of the autoplay
  /// "Up Next" section.
  Future<void> appendUpNext(List<MediaItem> items) async {
    if (items.isEmpty) return;
    for (final item in items) {
      await _player.add(toMedia(tagUpNext(item)));
    }
  }

  /// Removes the item at [index].
  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _player.state.playlist.medias.length) return;
    await _player.remove(index);
  }

  /// Moves the item from [oldIndex] to [newIndex].
  Future<void> move(int oldIndex, int newIndex) async {
    final len = _player.state.playlist.medias.length;
    if (oldIndex < 0 || oldIndex >= len) return;
    if (newIndex < 0 || newIndex >= len) return;
    if (oldIndex == newIndex) return;

    // Capture the up-next boundary BEFORE the move
    int? boundary;
    for (int i = 0; i < len; i++) {
      final it =
          _player.state.playlist.medias[i].extras?['mediaItem'] as MediaItem?;
      if (it != null && isUpNext(it)) {
        boundary = i;
        break;
      }
    }

    final toIndex = oldIndex < newIndex ? newIndex + 1 : newIndex;
    await _player.move(oldIndex, toIndex);
    await _retagMovedItem(newIndex, boundary);
  }

  /// Re-tags the item now sitting at [newIndex] based on the up-next
  /// [boundary] captured before the move.
  Future<void> _retagMovedItem(int newIndex, int? boundary) async {
    final playlist = _player.state.playlist;
    if (newIndex < 0 || newIndex >= playlist.medias.length) return;
    if (newIndex == playlist.index) return;

    final media = playlist.medias[newIndex];
    final item = media.extras?['mediaItem'] as MediaItem?;
    if (item == null) return;

    final target =
        (boundary == null || newIndex < boundary)
            ? QueueSection.user
            : QueueSection.upnext;
    if (sectionOf(item) == target) return;

    final retagged = tagSection(item, target);
    final newMedia = Media(
      media.uri,
      extras: {...?media.extras, 'mediaItem': retagged},
    );
    await replaceAtUnlocked(newIndex, newMedia);
  }

  /// Clears the entire queue.
  Future<void> clear() async {
    await _player.stop();
    await _player.open(const Playlist([]), play: false);
  }

  /// Removes every user-queue track, preserving the autoplay "Up Next" section.
  Future<void> purgeUserQueue() async {
    final medias = _player.state.playlist.medias;
    final currentIndex = _player.state.playlist.index;

    for (int i = medias.length - 1; i >= 0; i--) {
      if (i == currentIndex) continue;
      final item = medias[i].extras?['mediaItem'] as MediaItem?;
      if (item != null && !isUpNext(item)) {
        await _player.remove(i);
      }
    }
  }

  /// Removes every item currently tagged as upnext, leaving the user queue
  /// untouched.
  Future<void> purgeUpNext() async {
    final medias = _player.state.playlist.medias;
    final currentIndex = _player.state.playlist.index;

    for (int i = medias.length - 1; i >= 0; i--) {
      if (i == currentIndex) continue;
      final item = medias[i].extras?['mediaItem'] as MediaItem?;
      if (item != null && isUpNext(item)) {
        await _player.remove(i);
      }
    }
  }

  // ── Synchronization and persistence ────────────────────────────────────────

  /// Synchronizes the queue stream with the current playlist and persists to disk.
  ///
  /// Call after every queue mutation (add/remove/move) to keep the stream
  /// exposed to the UI and the database in sync.
  void syncQueue({bool isStopping = false}) {
    final playlist = _player.state.playlist;
    final items =
        playlist.medias
            .map((e) => e.extras?['mediaItem'] as MediaItem?)
            .nonNulls
            .toList();

    final newIds =
        items.map((e) => e.extras?['queueId'] as String? ?? e.id).toList();
    final currentIds =
        _getQueue()
            .map((e) => e.extras?['queueId'] as String? ?? e.id)
            .toList();
    final queueStructureChanged =
        newIds.length != currentIds.length ||
        !const ListEquality().equals(newIds, currentIds);

    // media_kit emits an empty playlist while `_player.open` is swapping in
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
      currentIndex: _player.state.playlist.index,
      shuffleMode: shuffleMode,
      repeatMode: repeatMode,
    );
  }

  /// Prepares a list of items for playlist opening.
  ///
  /// Assigns unique queueIds and converts to Media objects.
  /// Returns (itemsWithKeys, medias).
  (List<MediaItem>, List<Media>) preparePlaylist(
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

import 'dart:async';
import 'dart:developer' as dev;

import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/url_staleness.dart';
import '../../../domain/models/queue_section.dart';
import '../../../domain/models/queue_track.dart';
import '../../../domain/repositories/queue_repository.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';
import '../../providers/settings_provider.dart';
import 'playback_state_publisher.dart';
import 'queue_controller.dart';
import 'track_url_resolver.dart';

/// Represents the lifecycle of the player restore operation.
///
/// The UI observes this via [SonoraAudioHandler.restoreStatusStream] to decide
/// whether to show a loading indicator and block interactive controls.
enum RestoreStatus {
  /// No restore has been performed yet (initial state at startup).
  idle,

  /// A restore is in progress. The player is being rebuilt from the persisted
  /// queue. All interactive controls (play, pause, seek, skip) must be blocked.
  restoring,

  /// The player is ready. The current item has a valid URL, the seek position
  /// has been applied, and the user can interact normally.
  ready,
}

/// Handles cold-start queue restore and warm-resume URL refresh.
///
/// Does not hold a back-reference to [SonoraAudioHandler]; playback intent,
/// queue stream updates, and shuffle/repeat application are injected as narrow
/// callbacks.
class PlaybackRestoreController {
  final Player _player;
  final SharedPreferences _prefs;
  final QueueRepository _queueRepo;
  final QueueController _queueController;
  final TrackUrlResolver _urlResolver;
  final PlaybackStatePublisher _statePublisher;
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final void Function(bool) _setUserWantsPlaying;
  final MediaItem? Function() _currentMediaItem;
  final void Function(MediaItem) _emitMediaItem;
  final Future<void> Function(AudioServiceShuffleMode) _applyShuffleMode;
  final Future<void> Function(AudioServiceRepeatMode) _applyRepeatMode;
  final void Function(List<MediaItem>) _updateQueueStream;
  final void Function(bool) _setIsStopping;

  RestoreStatus _restoreStatus = RestoreStatus.idle;
  final StreamController<RestoreStatus> _restoreStatusController =
      StreamController<RestoreStatus>.broadcast();

  /// Completer that is uncompleted while [_restoreStatus] is [RestoreStatus.restoring].
  /// [play()] awaits this so that a notification/MPRIS play command issued
  /// during a restore does not race with the playlist rebuild.
  Completer<void> _readyCompleter = Completer<void>()..complete();

  /// The playback position read from SharedPreferences at restore time.
  /// Exposed so [PlayerNotifier] can pre-populate the seek bar immediately,
  /// before the player has actually seeked.
  Duration _savedPosition = Duration.zero;

  DateTime? _lastPauseTimestamp;

  /// Stream of [RestoreStatus] changes. [PlayerNotifier] subscribes here to
  /// drive the shimmer / loading UI and block interactive controls.
  Stream<RestoreStatus> get restoreStatusStream =>
      _restoreStatusController.stream;

  /// The current restore status (synchronous read for initial state).
  RestoreStatus get currentRestoreStatus => _restoreStatus;

  /// The playback position restored from disk.  Available as soon as
  /// [RestoreStatus.restoring] is emitted; used by [PlayerNotifier] to
  /// pre-populate the seek bar before the player has actually seeked.
  Duration get savedPosition => _savedPosition;

  DateTime? get lastPauseTimestamp => _lastPauseTimestamp;

  bool get isRestoring => _restoreStatus == RestoreStatus.restoring;

  void markPaused() {
    _lastPauseTimestamp = DateTime.now();
  }

  void clearPauseTimestamp() {
    _lastPauseTimestamp = null;
  }

  PlaybackRestoreController({
    required Player player,
    required SharedPreferences prefs,
    required QueueRepository queueRepo,
    required QueueController queueController,
    required TrackUrlResolver urlResolver,
    required PlaybackStatePublisher statePublisher,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required void Function(bool) setUserWantsPlaying,
    required MediaItem? Function() currentMediaItem,
    required void Function(MediaItem) emitMediaItem,
    required Future<void> Function(AudioServiceShuffleMode) applyShuffleMode,
    required Future<void> Function(AudioServiceRepeatMode) applyRepeatMode,
    required void Function(List<MediaItem>) updateQueueStream,
    required void Function(bool) setIsStopping,
  }) : _player = player,
       _prefs = prefs,
       _queueRepo = queueRepo,
       _queueController = queueController,
       _urlResolver = urlResolver,
       _statePublisher = statePublisher,
       _playVideoIdUseCase = playVideoIdUseCase,
       _setUserWantsPlaying = setUserWantsPlaying,
       _currentMediaItem = currentMediaItem,
       _emitMediaItem = emitMediaItem,
       _applyShuffleMode = applyShuffleMode,
       _applyRepeatMode = applyRepeatMode,
       _updateQueueStream = updateQueueStream,
       _setIsStopping = setIsStopping;

  Future<void> awaitReady() async {
    await _readyCompleter.future
        .timeout(const Duration(seconds: 3), onTimeout: () {})
        .catchError((_) {});
  }

  Future<void> ensureReady() => _ensureReady();

  void dispose() {
    _restoreStatusController.close();
  }

  void _setRestoreStatus(RestoreStatus status) {
    _restoreStatus = status;
    if (!_restoreStatusController.isClosed) {
      _restoreStatusController.add(status);
    }
    if (status == RestoreStatus.restoring) {
      // Create a fresh completer so play() blocks until restore completes.
      if (_readyCompleter.isCompleted) {
        _readyCompleter = Completer<void>();
      }
    } else {
      // ready or idle — unblock any awaiting play() call.
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete();
      }
    }
  }

  Future<void> _ensureReady() async {
    if (_restoreStatus == RestoreStatus.restoring) return;

    if (_player.state.playing) {
      _setRestoreStatus(RestoreStatus.ready);
      return;
    }

    final playlist = _player.state.playlist;
    if (playlist.medias.isNotEmpty) {
      // Warm resume: the process (and therefore the in-memory playlist) is
      // still alive — this is the common Android case, since the player
      // keeps a foreground service/notification running in the background
      // (androidStopForegroundOnPause: false). The in-memory queue/index
      // is the ground truth here and must be preserved as-is; it must NOT
      // be replaced by `_doRestore()`, which reloads a snapshot from disk
      // that can be behind the live state (e.g. an autoplay Up Next append
      // or a reorder whose disk write raced with backgrounding). Doing so
      // is what used to cause "wrong current song after reopening" and
      // "play stays stuck" on Android after the app sat idle for a while.
      final idx = playlist.index;
      if (idx >= 0 && idx < playlist.medias.length) {
        final item = playlist.medias[idx].extras?['mediaItem'] as MediaItem?;
        final track = item != null ? QueueTrack.fromMediaItem(item) : null;
        final isDummy = track?.url?.contains('localhost/dummy') == true;
        if (track != null &&
            !isDummy &&
            !UrlStaleness.isStale(
              track.url,
              lastPauseTimestamp: _lastPauseTimestamp,
            )) {
          _setRestoreStatus(RestoreStatus.ready);
          return;
        }

        // The current item's stream URL simply expired while backgrounded
        // (YouTube URLs embed an `expire` timestamp valid for a few hours).
        // Refresh it in place instead of rebuilding the whole playlist.
        // Freeze the position hint first so the seek bar doesn't jump while
        // RestoreStatus.restoring is briefly emitted (PlayerNotifier reads
        // `savedPosition` on that transition).
        _savedPosition = _player.state.position;
        _setRestoreStatus(RestoreStatus.restoring);
        try {
          await _urlResolver.resolveSinglePendingItem(idx, forceResolve: true);
        } finally {
          _setRestoreStatus(RestoreStatus.ready);
          _statePublisher.invalidate();
          _statePublisher.updatePlaybackState();
        }
        // Best-effort prefetch of the next item too; failures here are
        // non-fatal since it is not the one about to play.
        unawaited(
          _urlResolver
              .resolveSinglePendingItem(idx + 1, forceResolve: true)
              .catchError(
                (Object e) => dev.log(
                  '[AudioHandler] Warm-resume prefetch of next item failed: $e',
                ),
              ),
        );
        return;
      }
    }

    // Cold start: the in-memory playlist is empty (fresh process), rebuild
    // it from the persisted queue.
    _setRestoreStatus(RestoreStatus.restoring);
    try {
      await _doRestore();
    } catch (e, stack) {
      dev.log('[AudioHandler] Error in _ensureReady/_doRestore: $e\n$stack');
    } finally {
      _setRestoreStatus(RestoreStatus.ready);
      _statePublisher.invalidate();
      _statePublisher.updatePlaybackState();
    }
  }

  Future<void> _doRestore() async {
    // One-shot migration: the User/UpNext queue split was introduced with
    // schemaVersion 18. On the first startup after the upgrade, clear any
    // pre-split persisted queue so the new section-aware playback starts
    // from a clean state. The flag is set after the clear so the next
    // restore proceeds normally.
    final splitDone = _prefs.getBool(kPostQueueSplitDoneKey) ?? false;
    if (!splitDone) {
      dev.log(
        '[AudioHandler] Queue User/UpNext split: clearing legacy queue on '
        'first run after upgrade.',
      );
      // Clears both the queue rows AND the playback pointer (QueueMeta) in
      // one atomic transaction, so the player doesn't try to resume a song
      // from a queue/position that no longer exists.
      await _queueRepo.clearQueue();
      await _prefs.setBool(kPostQueueSplitDoneKey, true);
      // Fall through to the empty-queue restore path below.
    }

    final restoreOnStartup = _prefs.getBool('restoreQueueOnStartup') ?? true;
    if (!restoreOnStartup) return;

    final rawEntries = await _queueRepo.restoreQueueWithSections();
    if (rawEntries.isEmpty) return;

    // Honor the current autoplay setting: if the user disabled Up Next
    // between sessions, strip the upnext section from the restored queue.
    final autoplayEnabled = _prefs.getBool(kAutoPlayUpNextKey) ?? true;
    final filtered =
        autoplayEnabled
            ? rawEntries
            : rawEntries
                .where((entry) => entry.section == QueueSection.user)
                .toList();

    final seenIds = <String>{};
    final items =
        filtered.map((entry) {
          final track = entry.track;
          final baseItem = track.toFreshMediaItem();
          final taggedItem =
              entry.section == QueueSection.upnext
                  ? QueueController.tagUpNext(baseItem)
                  : QueueController.tagUser(baseItem);
          final isLocalAndValid =
              track.isLocalFile && !UrlStaleness.isStale(track.url!);
          if (isLocalAndValid) {
            return _queueController.ensureQueueId(taggedItem, seenIds);
          }
          return _queueController.ensureQueueId(
            track
                .copyWith(clearUrl: true, needsUrl: true)
                .toMediaItem(taggedItem),
            seenIds,
          );
        }).toList();

    _updateQueueStream(items);

    // The playback pointer (index/videoId anchor/position/shuffle/repeat) is
    // read from the SAME atomic record that the queue itself was written
    // with (see QueueRepositoryImpl.persistQueue) — no more split-brain
    // between SharedPreferences and the Drift queue table.
    final meta = await _queueRepo.restoreMeta();

    int savedIndex = meta.currentIndex;
    final anchorVideoId = meta.currentVideoId;
    final positionalMatchesAnchor =
        anchorVideoId != null &&
        savedIndex >= 0 &&
        savedIndex < items.length &&
        items[savedIndex].id == anchorVideoId;

    if (savedIndex < 0 || savedIndex >= items.length) {
      savedIndex = 0;
    }
    if (anchorVideoId != null && !positionalMatchesAnchor) {
      // The raw index no longer lines up with the last-known track (e.g.
      // items were removed from the persisted queue by some other flow
      // between sessions). Fall back to locating the track by its stable
      // videoId instead of trusting the numeric index, which otherwise
      // tends to resume into index 0 — a track the user was very likely
      // not listening to.
      final byId = items.indexWhere((it) => it.id == anchorVideoId);
      if (byId != -1) {
        dev.log(
          '[AudioHandler] _doRestore: index/anchor mismatch '
          '(saved index=$savedIndex, resolved by videoId=$byId). '
          'Using id-based match to avoid resuming the wrong track.',
        );
        savedIndex = byId;
      }
    }

    var currentItem = items[savedIndex];
    try {
      final freshUrl = await _playVideoIdUseCase.resolveUrl(currentItem.id);
      final track = QueueTrack.fromMediaItem(
        currentItem,
      ).copyWith(url: freshUrl, needsUrl: false);
      currentItem = track.toMediaItem(currentItem);
      items[savedIndex] = currentItem;
    } catch (e) {
      dev.log(
        '[AudioHandler] _doRestore: failed URL resolve for index $savedIndex: $e',
      );
    }

    _savedPosition = meta.position;

    if (meta.shuffleMode != null) {
      await _applyShuffleMode(meta.shuffleMode!);
    }

    if (meta.repeatMode != null) {
      await _applyRepeatMode(meta.repeatMode!);
    }

    _setIsStopping(false);
    final restoredPlaylist = Playlist(
      items.map(_queueController.toMedia).toList(),
      index: savedIndex,
    );
    _setUserWantsPlaying(false);

    // Open with play: true to trigger stream decoding (needed for the player
    // to report duration on streaming URLs). We pause right after the seek.
    // Suppress intermediate playlist events: media_kit briefly reports an
    // empty playlist during open, which would otherwise sync/persist [].
    _queueController.beginResolving();
    try {
      await _player.open(restoredPlaylist, play: true);

      if (_savedPosition > Duration.zero) {
        try {
          await _player.stream.duration
              .where((d) => d > Duration.zero)
              .first
              .timeout(const Duration(seconds: 8));
        } catch (_) {}
        await _player.seek(_savedPosition);
      }
      // Pause after restore — the user didn't ask for playback.
      if (_player.state.playing) {
        await _player.pause();
      }
    } finally {
      _queueController.endResolving();
      // Publish the final playlist to the queue stream before restore is
      // marked ready, so the full-player queue is populated immediately.
      _queueController.syncQueue(isStopping: false);
      // Seed mediaItem if playlist events were suppressed during open.
      final playlist = _player.state.playlist;
      final idx = playlist.index;
      if (idx >= 0 &&
          idx < playlist.medias.length &&
          _currentMediaItem() == null) {
        final item = playlist.medias[idx].extras?['mediaItem'] as MediaItem?;
        if (item != null) {
          _emitMediaItem(item);
        }
      }
      // Playlist events were suppressed during open, so queueIndex was never
      // published — and a concurrent look-ahead URL resolve can even stamp
      // queueIndex=0 while media_kit briefly reports index 0. Publish the
      // restored index explicitly so the queue highlight matches mediaItem.
      if (idx >= 0) {
        _statePublisher.updateState((s) => s.copyWith(queueIndex: idx));
      }
      _statePublisher.updatePlaybackState();
    }
  }
}

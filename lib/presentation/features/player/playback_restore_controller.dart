import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'playback_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/url_staleness.dart';
import '../../../data/services/media_cache_service.dart';
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
  final PlaybackEngine _engine;
  final SharedPreferences _prefs;
  final QueueRepository _queueRepo;
  final QueueController _queueController;
  final TrackUrlResolver _urlResolver;
  final PlaybackStatePublisher _statePublisher;
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final void Function(bool) _setUserWantsPlaying;
  final void Function(MediaItem) _emitMediaItem;
  final Future<void> Function(AudioServiceShuffleMode) _applyShuffleMode;
  final Future<void> Function(AudioServiceRepeatMode) _applyRepeatMode;
  final void Function(List<MediaItem>) _updateQueueStream;
  final void Function(bool) _setIsStopping;
  final void Function()? _onRestoreReady;

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

  /// Whether a persisted URL should be kept as a local file on restore.
  ///
  /// Media-cache hits are kept only when they are audio-only
  /// (`.webm`/`.m4a`/`.mp3`). Muxed `{id}.mp4` and video-only `{id}.v.*`
  /// files are discarded so restore always plays audio.
  @visibleForTesting
  static bool keepLocalUrlOnRestore(QueueTrack track) {
    if (!track.isLocalFile) return false;
    if (UrlStaleness.isStale(track.url)) return false;
    if (!MediaCacheService.isMediaCacheUri(track.url)) return true;
    return MediaCacheService.isCacheCompatibleWithPreferVideo(track.url, false);
  }

  void markPaused() {
    _lastPauseTimestamp = DateTime.now();
  }

  void clearPauseTimestamp() {
    _lastPauseTimestamp = null;
  }

  PlaybackRestoreController({
    required PlaybackEngine engine,
    required SharedPreferences prefs,
    required QueueRepository queueRepo,
    required QueueController queueController,
    required TrackUrlResolver urlResolver,
    required PlaybackStatePublisher statePublisher,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required void Function(bool) setUserWantsPlaying,
    required void Function(MediaItem) emitMediaItem,
    required Future<void> Function(AudioServiceShuffleMode) applyShuffleMode,
    required Future<void> Function(AudioServiceRepeatMode) applyRepeatMode,
    required void Function(List<MediaItem>) updateQueueStream,
    required void Function(bool) setIsStopping,
    void Function()? onRestoreReady,
  }) : _engine = engine,
       _prefs = prefs,
       _queueRepo = queueRepo,
       _queueController = queueController,
       _urlResolver = urlResolver,
       _statePublisher = statePublisher,
       _playVideoIdUseCase = playVideoIdUseCase,
       _setUserWantsPlaying = setUserWantsPlaying,
       _emitMediaItem = emitMediaItem,
       _applyShuffleMode = applyShuffleMode,
       _applyRepeatMode = applyRepeatMode,
       _updateQueueStream = updateQueueStream,
       _setIsStopping = setIsStopping,
       _onRestoreReady = onRestoreReady;

  Future<void> awaitReady() async {
    // Wait for cold/warm restore to finish before play/skip from AA or the
    // notification. A short abort used to race mid-open and start the wrong
    // index; keep a long safety bound so a hung restore cannot block forever.
    await _readyCompleter.future
        .timeout(readyWaitTimeout, onTimeout: () {})
        .catchError((_) {});
  }

  /// Upper bound for [awaitReady]. Must cover cold-restore URL resolve + seek.
  @visibleForTesting
  static const Duration readyWaitTimeout = Duration(seconds: 60);

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

    if (_engine.state.playing) {
      _setRestoreStatus(RestoreStatus.ready);
      return;
    }

    final playlist = _engine.state.playlist;
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
        final item = playlist.medias[idx].mediaItem;
        final track = item != null ? QueueTrack.fromMediaItem(item) : null;
        final isDummy = track?.url?.contains('localhost/dummy') == true;
        if (track != null &&
            !isDummy &&
            !UrlStaleness.isStale(
              track.url,
              lastPauseTimestamp: _lastPauseTimestamp,
            )) {
          _setRestoreStatus(RestoreStatus.ready);
          _onRestoreReady?.call();
          return;
        }

        // The current item's stream URL simply expired while backgrounded
        // (YouTube URLs embed an `expire` timestamp valid for a few hours).
        // Refresh it in place instead of rebuilding the whole playlist.
        // Freeze the position hint first so the seek bar doesn't jump while
        // RestoreStatus.restoring is briefly emitted (PlayerNotifier reads
        // `savedPosition` on that transition).
        _savedPosition = _engine.state.position;
        _setRestoreStatus(RestoreStatus.restoring);
        try {
          await _urlResolver.resolveSinglePendingItem(idx, forceResolve: true);
        } finally {
          _setRestoreStatus(RestoreStatus.ready);
          _statePublisher.invalidate();
          _statePublisher.updatePlaybackState();
          _onRestoreReady?.call();
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
      _onRestoreReady?.call();
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
              PlaybackRestoreController.keepLocalUrlOnRestore(track);
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
    // Publish metadata immediately so Android Auto can show the now-playing
    // chrome while the stream URL is still resolving (STATE_NONE / idle hides
    // the player until the user picks a track from browse).
    _savedPosition = meta.position;
    _emitMediaItem(currentItem);
    _statePublisher.publishConnecting(
      queueIndex: savedIndex,
      position: _savedPosition,
    );

    try {
      final currentTrack = QueueTrack.fromMediaItem(currentItem);
      final freshUrl = await _playVideoIdUseCase.resolveUrl(
        currentItem.id,
        preferVideo: _queueController.prefersVideo(currentTrack),
      );
      final track = QueueTrack.fromMediaItem(
        currentItem,
      ).copyWith(url: freshUrl, needsUrl: false);
      currentItem = track.toMediaItem(currentItem);
      items[savedIndex] = currentItem;
      _emitMediaItem(currentItem);
    } catch (e) {
      dev.log(
        '[AudioHandler] _doRestore: failed URL resolve for index $savedIndex: $e',
      );
    }

    if (meta.shuffleMode != null) {
      await _applyShuffleMode(meta.shuffleMode!);
    }

    if (meta.repeatMode != null) {
      await _applyRepeatMode(meta.repeatMode!);
    }

    _setIsStopping(false);
    final restoredMedias = items.map(_queueController.toMedia).toList();
    _setUserWantsPlaying(false);

    // Load paused at the persisted index/position. just_audio's preload
    // already reports duration without starting playback; play:true was a
    // media_kit workaround that produced a ~1s audio blip on cold start.
    _queueController.beginResolving();
    try {
      await _engine.open(
        restoredMedias,
        index: savedIndex,
        play: false,
        position: _savedPosition,
      );

      // The engine may briefly report index 0 while opening a non-zero playlist
      // index. Wait for the intended item before seeking so the seek is not
      // applied to the wrong track.
      if (savedIndex > 0 && _engine.state.playlist.index != savedIndex) {
        try {
          await _engine.playlistStream
              .where((p) => p.index == savedIndex)
              .first
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          if (_engine.state.playlist.index != savedIndex) {
            await _engine.jump(savedIndex);
          }
        }
      }

      if (_savedPosition > Duration.zero) {
        try {
          await _engine.durationStream
              .where((d) => d > Duration.zero)
              .first
              .timeout(const Duration(seconds: 8));
        } catch (_) {}
        await _engine.seek(_savedPosition);
        // Video/HLS seeks complete asynchronously: await returns while
        // position is still 0. Wait until the demuxer reports a position near
        // the target before pausing / ending restore (otherwise UI + persist
        // race to 0 and wipe the restored pointer).
        const tolerance = Duration(seconds: 2);
        try {
          await _engine.positionStream
              .where((p) => (p - _savedPosition).abs() <= tolerance)
              .first
              .timeout(const Duration(seconds: 8));
        } catch (_) {
          // One retry — first seek can be ignored if the stream was not
          // fully ready yet despite duration > 0.
          await _engine.seek(_savedPosition);
          try {
            await _engine.positionStream
                .where((p) => (p - _savedPosition).abs() <= tolerance)
                .first
                .timeout(const Duration(seconds: 5));
          } catch (_) {}
        }
      }
      // Pause after restore — the user didn't ask for playback.
      if (_engine.state.playing) {
        await _engine.pause();
      }
    } finally {
      _queueController.endResolving();
      // Publish the final playlist to the queue stream before restore is
      // marked ready, so the full-player queue is populated immediately.
      _queueController.syncQueue(isStopping: false);
      // Seed / refresh mediaItem after open (URL may have been resolved above).
      final playlist = _engine.state.playlist;
      final idx = playlist.index;
      if (idx >= 0 && idx < playlist.medias.length) {
        final item = playlist.medias[idx].mediaItem;
        if (item != null) {
          _emitMediaItem(item);
        }
      }
      // Playlist events were suppressed during open, so queueIndex was never
      // published — and a concurrent look-ahead URL resolve can even stamp
      // queueIndex=0 while the engine briefly reports index 0. Publish the
      // restored index explicitly so the queue highlight matches mediaItem.
      if (idx >= 0) {
        _statePublisher.updateState((s) => s.copyWith(queueIndex: idx));
      }
      _statePublisher.updatePlaybackState();
    }
  }
}

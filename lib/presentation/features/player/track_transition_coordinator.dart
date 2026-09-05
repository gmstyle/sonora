import 'dart:async';
import 'dart:developer' as dev;

import 'package:audio_service/audio_service.dart';
import 'playback_engine.dart';

import '../../../domain/models/queue_track.dart';
import '../../../domain/repositories/queue_repository.dart';
import '../../providers/cast_provider.dart';
import 'cast_playback_controller.dart';
import 'like_controller.dart';
import 'playback_intent_controller.dart';
import 'playback_recovery_controller.dart';
import 'playback_state_publisher.dart';
import 'playback_volume_controller.dart';
import 'player_media_controls.dart';
import 'queue_controller.dart';
import 'skip_navigator.dart';
import 'track_url_resolver.dart';

/// Wires [PlaybackEngine] streams and runs the track-change cascade.
///
/// [setupListeners] owns the subscriptions; [onPlaylistChanged] is the cascade
/// itself. This is the most order-sensitive code in the player module. The
/// steps below are not independent, and a mechanically correct extraction that
/// reorders two of them breaks casting or queue persistence with nothing to
/// signal it.
///
/// ## The cascade, in order
///
/// 1. **Bail out if stopping.** A `stop()` in flight must not repopulate state.
/// 2. **Queue pointer.** Clear the skip target, publish `queueIndex`, and
///    persist index + videoId atomically. Persisting on every track change,
///    not just on structural queue changes, is what stops the "where were we"
///    pointer from lagging behind after a process restart.
/// 3. **Media item.** Patch the duration if it is safe to do so, publish, and
///    on a genuine track change reset the retry counter, refresh the liked
///    state, and hand the track to the cast device.
/// 4. **Resolve.** Kick off lazy URL resolution and look-ahead.
/// 5. **Sync queue.** Reconcile the `audio_service` queue with the playlist.
/// 6. **Fade in.**
///
/// ## The role of `isResolvingItem`
///
/// While the resolver is swapping a URL into the playlist, the engine emits
/// playlist events for what is really the *same* track. Steps 2, 3, 5 and 6 are
/// suppressed during that window, otherwise every look-ahead resolve would
/// republish the media item, re-persist the pointer and re-trigger a fade.
///
/// Step 4 is deliberately **not** suppressed during URL resolve: it is the
/// resolver's own driver — gating it would stall look-ahead permanently.
/// Cold restore is the exception: the engine briefly reports index 0 while
/// opening a non-zero playlist, and look-ahead of those placeholders would
/// replace sources *before* the current index. On just_audio_media_kit that
/// drops currentIndex by 1. Restore starts look-ahead itself after open.
class TrackTransitionCoordinator {
  final PlaybackEngine _engine;
  final PlaybackIntentController _intent;
  final QueueController _queueController;
  final SkipNavigator _skipNavigator;
  final PlaybackStatePublisher _statePublisher;
  final QueueRepository _queueRepo;
  final PlaybackRecoveryController Function() _recoveryController;
  final LikeController _likeController;
  final CastPlaybackController Function() _castController;
  final TrackUrlResolver _urlResolver;
  final PlaybackVolumeController _volumeController;
  final MediaItem? Function() _currentMediaItem;
  final void Function(MediaItem) _emitMediaItem;
  final bool Function() _isStopping;
  final bool Function() _isRestoring;
  final bool Function() _isShuffleAll;
  final bool Function() _isRepeatOne;
  final Future<void> Function()? _skipToNext;
  final Future<void> Function(int index)? _skipToQueueItem;
  int? _previousPlaylistIndex;
  bool _shuffleEndArmed = false;

  TrackTransitionCoordinator({
    required PlaybackEngine engine,
    required PlaybackIntentController intent,
    required QueueController queueController,
    required SkipNavigator skipNavigator,
    required PlaybackStatePublisher statePublisher,
    required QueueRepository queueRepo,
    required PlaybackRecoveryController Function() recoveryController,
    required LikeController likeController,
    required CastPlaybackController Function() castController,
    required TrackUrlResolver urlResolver,
    required PlaybackVolumeController volumeController,
    required MediaItem? Function() currentMediaItem,
    required void Function(MediaItem) emitMediaItem,
    required bool Function() isStopping,
    required bool Function() isRestoring,
    bool Function()? isShuffleAll,
    bool Function()? isRepeatOne,
    Future<void> Function()? skipToNext,
    Future<void> Function(int index)? skipToQueueItem,
  }) : _engine = engine,
       _intent = intent,
       _queueController = queueController,
       _skipNavigator = skipNavigator,
       _statePublisher = statePublisher,
       _queueRepo = queueRepo,
       _recoveryController = recoveryController,
       _likeController = likeController,
       _castController = castController,
       _urlResolver = urlResolver,
       _volumeController = volumeController,
       _currentMediaItem = currentMediaItem,
       _emitMediaItem = emitMediaItem,
       _isStopping = isStopping,
       _isRestoring = isRestoring,
       _isShuffleAll = isShuffleAll ?? (() => false),
       _isRepeatOne = isRepeatOne ?? (() => false),
       _skipToNext = skipToNext,
       _skipToQueueItem = skipToQueueItem;

  /// Subscribes to engine streams. Called once from the handler constructor.
  void setupListeners() {
    _engine.playingStream.listen((playing) {
      if (_intent.shouldForcePause(playing: playing)) {
        unawaited(_engine.pause());
        return;
      }
      _intent.onEnginePlaying(
        playing,
        suppressClear:
            _isRestoring() ||
            _volumeController.isTransitionMuted ||
            _castController().pausedForConnection,
      );
      _statePublisher.updatePlaybackState();
    });
    _engine.bufferingStream.listen(
      (_) => _statePublisher.updatePlaybackState(),
    );
    _engine.completedStream.listen(
      (_) => _statePublisher.updatePlaybackState(),
    );

    _engine.playlistStream.listen((playlist) {
      final previousIndex = _previousPlaylistIndex;
      if (_redirectShuffleAutoAdvance(previousIndex, playlist.index)) {
        _previousPlaylistIndex = playlist.index;
        return;
      }
      _previousPlaylistIndex = playlist.index;
      // Keep emitting while the engine is already audible; dropping this
      // during URL resolve froze PlaybackState.playing=false (mini-player
      // shimmer).
      if (!_queueController.isResolvingItem || _engine.state.playing) {
        _statePublisher.updatePlaybackState();
      }
      onPlaylistChanged(playlist);
    });

    _engine.durationStream.listen(onDurationChanged);

    _engine.positionStream.listen((pos) {
      _volumeController.handleCrossfade(pos);
      _statePublisher.handlePositionTick(pos);
      _maybeShuffleAdvanceNearEnd(pos);
      if (_volumeController.isTransitionMuted &&
          _engine.state.playing &&
          pos.inMilliseconds > 150) {
        _volumeController.endTransitionMute();
      }
    });
    _engine.bufferedPositionStream.listen(
      _statePublisher.onBufferedPositionChanged,
    );

    _engine.shuffleStream.listen((shuffled) {
      final shuffleMode =
          shuffled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;
      _statePublisher.updateState((s) => s.copyWith(shuffleMode: shuffleMode));
      rebuildControls();
    });

    _engine.repeatModeStream.listen((mode) {
      final repeatMode = switch (mode) {
        EngineRepeatMode.none => AudioServiceRepeatMode.none,
        EngineRepeatMode.one => AudioServiceRepeatMode.one,
        EngineRepeatMode.all => AudioServiceRepeatMode.all,
      };
      _statePublisher.updateState((s) => s.copyWith(repeatMode: repeatMode));
      rebuildControls();
    });
  }

  /// just_audio concatenates in list order and never emits `completed` between
  /// items, so Dart-side shuffle must intercept engine auto-advance (`+1`).
  bool _redirectShuffleAutoAdvance(int? previousIndex, int newIndex) {
    final jump = _skipToQueueItem;
    if (jump == null) return false;
    if (!_isShuffleAll() || _isRepeatOne()) return false;
    if (_skipNavigator.targetSkipIndex != null) return false;
    if (previousIndex == null || newIndex != previousIndex + 1) return false;

    final len = _engine.state.playlist.medias.length;
    final nextIndex = SkipNavigator.computeNextIndex(
      length: len,
      currentTarget: previousIndex,
      shuffle: true,
      repeatAll: true,
    );
    _skipNavigator.recordForwardSkip(previousIndex);
    _skipNavigator.targetSkipIndex = nextIndex;
    unawaited(jump(nextIndex));
    return true;
  }

  void _maybeShuffleAdvanceNearEnd(Duration pos) {
    final skip = _skipToNext;
    if (skip == null) return;
    if (!_isShuffleAll() || _isRepeatOne() || !_engine.state.playing) {
      _shuffleEndArmed = false;
      return;
    }
    final duration = _engine.state.duration;
    if (duration < const Duration(seconds: 5)) {
      _shuffleEndArmed = false;
      return;
    }
    final remaining = duration - pos;
    if (remaining <= const Duration(milliseconds: 450) &&
        remaining >= Duration.zero) {
      if (_shuffleEndArmed) return;
      _shuffleEndArmed = true;
      unawaited(skip());
    } else if (remaining > const Duration(seconds: 2)) {
      _shuffleEndArmed = false;
    }
  }

  /// Rebuilds the notification / Android Auto control row (play, shuffle, like).
  void rebuildControls() {
    _statePublisher.updateState(
      (s) => s.copyWith(
        controls: PlayerMediaControls.build(
          s,
          isLiked: _likeController.isCurrentSongLiked,
        ),
      ),
    );
  }

  void onPlaylistChanged(EnginePlaylist playlist) {
    if (_isStopping()) return;

    final index = playlist.index;

    if (!_queueController.isResolvingItem) {
      _publishQueuePointer(playlist, index);
    }

    if (!_queueController.isResolvingItem &&
        index >= 0 &&
        index < playlist.medias.length) {
      _publishMediaItem(playlist.medias[index]);
    }

    // Look-ahead is the resolver's driver and is not gated by isResolvingItem.
    // Skip it during cold restore — the engine emits index 0 before the
    // persisted slot, and replacing those earlier placeholders drops the
    // restored currentIndex (x → x-1). Restore kicks off look-ahead itself
    // once the playlist is open at the saved index.
    if (!_isRestoring()) {
      unawaited(
        _urlResolver
            .resolvePendingItems(index)
            .catchError(
              (Object e) =>
                  dev.log('[AudioHandler] _resolvePendingItems error: $e'),
            ),
      );
    }

    if (!_queueController.isResolvingItem) {
      _queueController.syncQueue(isStopping: _isStopping());
    }

    if (!_queueController.isResolvingItem) {
      _volumeController.beginFadeIn();
    }
  }

  void _publishQueuePointer(EnginePlaylist playlist, int index) {
    _skipNavigator.clearTarget();
    if (!_isRestoring()) {
      _statePublisher.updateState((s) => s.copyWith(queueIndex: index));
    }
    if (index < 0) return;

    // Persist the raw index alongside the item's stable identity (its
    // videoId) in the SAME atomic QueueMeta row that the queue itself
    // is persisted to (see `QueueRepositoryImpl`). Doing this on every
    // track change — not just when the queue's structure changes — means
    // the "where were we" pointer can never lag behind the actually-playing
    // track, which used to cause resuming into a stale/wrong index after a
    // process restart.
    final currentMediaItem =
        index < playlist.medias.length
            ? playlist.medias[index].mediaItem
            : null;
    final videoId =
        currentMediaItem != null
            ? QueueTrack.fromMediaItem(currentMediaItem).videoId
            : null;
    // Empty playlist events during cold restore were writing index=0 and
    // videoId=null to QueueMeta *before* restoreMeta() ran, wiping a
    // correct pointer (e.g. Dance Monkey @ 0:55 → Calm Down @ 0:55).
    if (_isRestoring() || currentMediaItem == null) return;
    unawaited(_queueRepo.persistCurrentIndex(index, videoId: videoId));
  }

  void _publishMediaItem(EngineMedia media) {
    var item = media.mediaItem;
    if (item == null) return;

    var track = QueueTrack.fromMediaItem(item);
    final playerDuration = _engine.state.duration;
    final trackChanged =
        track.videoId != _statePublisher.lastEmittedMediaItemId;

    // On track change, player.state.duration is often still the *previous*
    // track's length — copying it here stamps a stale duration and then
    // blocks the real player duration patch (skipAlreadySet).
    if (!trackChanged &&
        (track.duration == null || track.duration == Duration.zero) &&
        playerDuration != Duration.zero) {
      track = track.copyWith(duration: playerDuration);
      item = track.toMediaItem(item);
    }

    final durationResolved =
        !trackChanged &&
        (_statePublisher.lastEmittedDuration == null ||
            _statePublisher.lastEmittedDuration == Duration.zero) &&
        (track.duration != null && track.duration != Duration.zero);
    if (!trackChanged && !durationResolved) return;

    _statePublisher.noteEmittedMediaItem(item, track: track);
    _emitMediaItem(item);
    if (!trackChanged) return;

    _recoveryController().resetRetryCount();
    _likeController.checkCurrentSongLiked(track.videoId);
    _castCurrentTrack(item, track);
  }

  void _castCurrentTrack(MediaItem item, QueueTrack track) {
    final cast = _castController();
    if (cast.castState?.connectionState != CastConnectionState.connected) {
      return;
    }
    if (track.needsUrl) return;

    unawaited(
      cast
          .castSong(item, cast.castState!, cast.castService!)
          .catchError(
            (Object e) => dev.log('[AudioHandler] castSong error: $e'),
          ),
    );
  }

  /// Stamps a duration onto the published media item once the engine reports it.
  ///
  /// Resolve can suppress the [onPlaylistChanged] media-item update across a
  /// skip, so `mediaItem` may still hold the previous track while the player has
  /// already moved on. The duration is therefore bound to the playlist identity
  /// rather than to whatever is currently published.
  void onDurationChanged(Duration duration) {
    // Duration is independent of URL resolve; do not drop updates while
    // isResolvingItem (look-ahead) or AA seekbar stays at 0 forever when
    // the engine emits duration only once during that window.
    if (duration == Duration.zero) return;

    final playlist = _engine.state.playlist;
    final index = playlist.index;
    MediaItem? playingItem;
    if (index >= 0 && index < playlist.medias.length) {
      playingItem = playlist.medias[index].mediaItem;
    }

    final current = _currentMediaItem();
    final playingTrack =
        playingItem != null ? QueueTrack.fromMediaItem(playingItem) : null;
    final currentTrack =
        current != null ? QueueTrack.fromMediaItem(current) : null;

    if (playingTrack != null &&
        playingItem != null &&
        (currentTrack == null ||
            currentTrack.videoId != playingTrack.videoId)) {
      final updatedTrack =
          (playingTrack.duration != null &&
                  playingTrack.duration != Duration.zero)
              ? playingTrack
              : playingTrack.copyWith(duration: duration);
      final updated = updatedTrack.toMediaItem(playingItem);
      _statePublisher.noteEmittedMediaItem(updated, track: updatedTrack);
      _emitMediaItem(updated);
      return;
    }

    if (current == null || currentTrack == null) return;
    if (currentTrack.duration != null &&
        currentTrack.duration != Duration.zero) {
      return;
    }
    final updatedTrack = currentTrack.copyWith(duration: duration);
    final updated = updatedTrack.toMediaItem(current);
    _statePublisher.noteEmittedMediaItem(updated, track: updatedTrack);
    _emitMediaItem(updated);
  }
}

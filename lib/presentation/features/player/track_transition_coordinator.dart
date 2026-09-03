import 'dart:async';
import 'dart:developer' as dev;

import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';

import '../../../domain/models/queue_track.dart';
import '../../../domain/repositories/queue_repository.dart';
import '../../providers/cast_provider.dart';
import 'cast_playback_controller.dart';
import 'external_audio_track_controller.dart';
import 'like_controller.dart';
import 'playback_intent_controller.dart';
import 'playback_recovery_controller.dart';
import 'playback_state_publisher.dart';
import 'playback_volume_controller.dart';
import 'player_media_controls.dart';
import 'queue_controller.dart';
import 'skip_navigator.dart';
import 'track_url_resolver.dart';

/// Wires media_kit player streams and runs the track-change cascade.
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
/// 2. **External audio.** Attach or detach the separate audio file for a
///    cached video-only track. Runs *before* anything reads player state,
///    because the track has to be complete before it is published.
/// 3. **Queue pointer.** Clear the skip target, publish `queueIndex`, and
///    persist index + videoId atomically. Persisting on every track change,
///    not just on structural queue changes, is what stops the "where were we"
///    pointer from lagging behind after a process restart.
/// 4. **Media item.** Patch the duration if it is safe to do so, publish, and
///    on a genuine track change reset the retry counter, refresh the liked
///    state, and hand the track to the cast device.
/// 5. **Resolve.** Kick off lazy URL resolution and look-ahead.
/// 6. **Sync queue.** Reconcile the `audio_service` queue with the playlist.
/// 7. **Fade in.**
///
/// ## The role of `isResolvingItem`
///
/// While the resolver is swapping a URL into the playlist, media_kit emits
/// playlist events for what is really the *same* track. Steps 3, 4, 6 and 7 are
/// suppressed during that window, otherwise every look-ahead resolve would
/// republish the media item, re-persist the pointer and re-trigger a fade.
///
/// Steps 2 and 5 are deliberately **not** suppressed: the external audio track
/// has to follow the playlist even mid-resolve, and step 5 is the resolver's
/// own driver — gating it would stall look-ahead permanently.
class TrackTransitionCoordinator {
  final Player _player;
  final PlaybackIntentController _intent;
  final ExternalAudioTrackController _externalAudio;
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

  TrackTransitionCoordinator({
    required Player player,
    required PlaybackIntentController intent,
    required ExternalAudioTrackController externalAudio,
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
  }) : _player = player,
       _intent = intent,
       _externalAudio = externalAudio,
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
       _isRestoring = isRestoring;

  /// Subscribes to media_kit streams. Called once from the handler constructor.
  void setupListeners() {
    _player.stream.playing.listen((playing) {
      if (_intent.shouldForcePause(playing: playing)) {
        unawaited(_player.pause());
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
    _player.stream.buffering.listen(
      (_) => _statePublisher.updatePlaybackState(),
    );
    _player.stream.completed.listen(
      (_) => _statePublisher.updatePlaybackState(),
    );

    _player.stream.playlist.listen((playlist) {
      if (!_queueController.isResolvingItem) {
        _statePublisher.updatePlaybackState();
      }
      onPlaylistChanged(playlist);
    });

    _player.stream.duration.listen(onDurationChanged);

    _player.stream.position.listen((pos) {
      _volumeController.handleCrossfade(pos);
      _statePublisher.handlePositionTick(pos);
      if (_volumeController.isTransitionMuted &&
          _player.state.playing &&
          pos.inMilliseconds > 150) {
        _volumeController.endTransitionMute();
      }
    });
    _player.stream.buffer.listen(_statePublisher.onBufferedPositionChanged);

    _player.stream.shuffle.listen((shuffled) {
      final shuffleMode =
          shuffled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;
      _statePublisher.updateState((s) => s.copyWith(shuffleMode: shuffleMode));
      rebuildControls();
    });

    _player.stream.playlistMode.listen((mode) {
      final repeatMode = switch (mode) {
        PlaylistMode.none => AudioServiceRepeatMode.none,
        PlaylistMode.single => AudioServiceRepeatMode.one,
        PlaylistMode.loop => AudioServiceRepeatMode.all,
      };
      _statePublisher.updateState((s) => s.copyWith(repeatMode: repeatMode));
      rebuildControls();
    });
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

  void onPlaylistChanged(Playlist playlist) {
    if (_isStopping()) return;

    final index = playlist.index;

    // 2 — external audio, never suppressed
    if (index >= 0 && index < playlist.medias.length) {
      unawaited(_externalAudio.attachForMedia(playlist.medias[index]));
    } else {
      unawaited(_externalAudio.attachForMedia(null));
    }

    if (!_queueController.isResolvingItem) {
      _publishQueuePointer(playlist, index);
    }

    if (!_queueController.isResolvingItem &&
        index >= 0 &&
        index < playlist.medias.length) {
      _publishMediaItem(playlist.medias[index]);
    }

    // 5 — the resolver's driver, never suppressed
    unawaited(
      _urlResolver
          .resolvePendingItems(index)
          .catchError(
            (Object e) =>
                dev.log('[AudioHandler] _resolvePendingItems error: $e'),
          ),
    );

    if (!_queueController.isResolvingItem) {
      _queueController.syncQueue(isStopping: _isStopping());
    }

    if (!_queueController.isResolvingItem) {
      _volumeController.beginFadeIn();
    }
  }

  void _publishQueuePointer(Playlist playlist, int index) {
    _skipNavigator.clearTarget();
    _statePublisher.updateState((s) => s.copyWith(queueIndex: index));
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
            ? (playlist.medias[index].extras?['mediaItem'] as MediaItem?)
            : null;
    final videoId =
        currentMediaItem != null
            ? QueueTrack.fromMediaItem(currentMediaItem).videoId
            : null;
    unawaited(_queueRepo.persistCurrentIndex(index, videoId: videoId));
  }

  void _publishMediaItem(Media media) {
    var item = media.extras?['mediaItem'] as MediaItem?;
    if (item == null) return;

    var track = QueueTrack.fromMediaItem(item);
    final playerDuration = _player.state.duration;
    final trackChanged = track.videoId != _statePublisher.lastEmittedMediaItemId;

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
    if (cast.castState?.connectionState != CastConnectionState.connected) return;
    if (track.needsUrl) return;

    unawaited(
      cast
          .castSong(item, cast.castState!, cast.castService!)
          .catchError(
            (Object e) => dev.log('[AudioHandler] castSong error: $e'),
          ),
    );
  }

  /// Stamps a duration onto the published media item once media_kit reports it.
  ///
  /// Resolve can suppress the [onPlaylistChanged] media-item update across a
  /// skip, so `mediaItem` may still hold the previous track while the player has
  /// already moved on. The duration is therefore bound to the playlist identity
  /// rather than to whatever is currently published.
  void onDurationChanged(Duration duration) {
    // Duration is independent of URL resolve; do not drop updates while
    // isResolvingItem (look-ahead) or AA seekbar stays at 0 forever when
    // media_kit emits duration only once during that window.
    if (duration == Duration.zero) return;

    final playlist = _player.state.playlist;
    final index = playlist.index;
    MediaItem? playingItem;
    if (index >= 0 && index < playlist.medias.length) {
      playingItem = playlist.medias[index].extras?['mediaItem'] as MediaItem?;
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

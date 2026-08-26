import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../../../domain/models/queue_track.dart';
import 'player_media_controls.dart';

/// Projects media_kit player state into audio_service [PlaybackState], with
/// dedupe so Android Auto / notification hosts are not spammed.
///
/// Does not hold a back-reference to [SonoraAudioHandler]; stream accessors and
/// restore state are injected as narrow callbacks.
class PlaybackStatePublisher {
  final Player _player;
  final PlaybackState Function() _getPlaybackState;
  final void Function(PlaybackState) _setPlaybackState;
  final bool Function() _isRestoring;
  final bool Function() _isResolving;
  final Duration Function() _savedPosition;
  final bool Function() _isLiked;
  final void Function() _onBecameReady;

  Duration _lastPosition = Duration.zero;
  String? _lastEmittedMediaItemId;
  Duration? lastEmittedDuration;
  AudioProcessingState? _lastEmittedProcessingState;
  bool? _lastEmittedPlaying;

  PlaybackStatePublisher({
    required Player player,
    required PlaybackState Function() getPlaybackState,
    required void Function(PlaybackState) setPlaybackState,
    required bool Function() isRestoring,
    required bool Function() isResolving,
    required Duration Function() savedPosition,
    required bool Function() isLiked,
    required void Function() onBecameReady,
  }) : _player = player,
       _getPlaybackState = getPlaybackState,
       _setPlaybackState = setPlaybackState,
       _isRestoring = isRestoring,
       _isResolving = isResolving,
       _savedPosition = savedPosition,
       _isLiked = isLiked,
       _onBecameReady = onBecameReady;

  String? get lastEmittedMediaItemId => _lastEmittedMediaItemId;

  /// True while playlist may be transiently empty (open / replace / restore).
  /// Publishing [AudioProcessingState.idle] in that window stops the Android
  /// MediaSession (`audio_service` calls `_stop()` on idle), which kills
  /// Android Auto transport controls until a process restart.
  bool get isSuppressingIdle => _isRestoring() || _isResolving();

  /// Forces the next [updatePlaybackState] to emit even if processing/playing
  /// appear unchanged. Used after focus denial, cast URL swaps, etc.
  void invalidate() {
    _lastEmittedProcessingState = null;
    _lastEmittedPlaying = null;
  }

  void noteEmittedMediaItem(MediaItem item, {QueueTrack? track}) {
    final t = track ?? QueueTrack.fromMediaItem(item);
    _lastEmittedMediaItemId = t.videoId;
    lastEmittedDuration = t.duration;
  }

  /// Maps raw player flags to an [AudioProcessingState].
  ///
  /// When [playlistEmpty] is true and [suppressingIdle] is true (open / URL
  /// replace / restore), returns [AudioProcessingState.buffering] instead of
  /// [AudioProcessingState.idle] so `audio_service` does not tear down the
  /// MediaSession.
  @visibleForTesting
  static AudioProcessingState resolveProcessingState({
    required bool buffering,
    required bool completed,
    required bool playlistEmpty,
    required bool suppressingIdle,
  }) {
    if (buffering) {
      return AudioProcessingState.buffering;
    }
    if (completed) {
      return AudioProcessingState.completed;
    }
    if (playlistEmpty) {
      if (suppressingIdle) {
        return AudioProcessingState.buffering;
      }
      return AudioProcessingState.idle;
    }
    return AudioProcessingState.ready;
  }

  AudioProcessingState getProcessingState() {
    return resolveProcessingState(
      buffering: _player.state.buffering,
      completed: _player.state.completed,
      playlistEmpty: _player.state.playlist.medias.isEmpty,
      suppressingIdle: isSuppressingIdle,
    );
  }

  void updatePlaybackState() {
    if (_isRestoring() || _isResolving()) return;

    final processing = getProcessingState();
    final playing = _player.state.playing;

    if (processing == AudioProcessingState.ready) {
      _onBecameReady();
    }

    final stateUnchanged =
        processing == _lastEmittedProcessingState &&
        playing == _lastEmittedPlaying;
    if (stateUnchanged) return;

    _lastEmittedProcessingState = processing;
    _lastEmittedPlaying = playing;

    final current = _getPlaybackState();
    final updatedState = current.copyWith(
      processingState: processing,
      playing: playing,
      updatePosition: _player.state.position,
      speed: _player.state.rate,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setRating,
      },
      androidCompactActionIndices: const [0, 1, 2],
    );

    _setPlaybackState(
      updatedState.copyWith(
        controls: PlayerMediaControls.build(updatedState, isLiked: _isLiked()),
      ),
    );
  }

  void updateState(
    PlaybackState Function(PlaybackState) update, {
    Duration? forcePosition,
  }) {
    final current = _getPlaybackState();
    final updated = update(current);
    final position =
        forcePosition ??
        (_isRestoring() ? _savedPosition() : _player.state.position);
    _setPlaybackState(
      updated.copyWith(updatePosition: position, speed: _player.state.rate),
    );
  }

  void onBufferedPositionChanged(Duration position) {
    final prev = _getPlaybackState().bufferedPosition;
    if ((position - prev).abs() >= const Duration(seconds: 2)) {
      updateState((s) => s.copyWith(bufferedPosition: position));
    }
  }

  void handlePositionTick(Duration pos) {
    final jumpedBackward =
        pos < _lastPosition - const Duration(milliseconds: 500);
    final advancedEnough = pos >= _lastPosition + const Duration(seconds: 1);
    if (jumpedBackward || advancedEnough) {
      updateState((s) => s);
    }
    _lastPosition = pos;
  }

  /// Publishes a non-idle [AudioProcessingState.loading] while cold restore is
  /// still resolving the stream URL. Android Auto hides the now-playing UI on
  /// [AudioProcessingState.idle] / STATE_NONE — so we must leave idle as soon
  /// as we know which track will resume.
  void publishConnecting({required int queueIndex, Duration? position}) {
    final current = _getPlaybackState();
    final updated = current.copyWith(
      processingState: AudioProcessingState.loading,
      playing: false,
      queueIndex: queueIndex,
      updatePosition:
          position ??
          (_isRestoring() ? _savedPosition() : _player.state.position),
      speed: _player.state.rate,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setRating,
      },
      androidCompactActionIndices: const [0, 1, 2],
    );
    _lastEmittedProcessingState = AudioProcessingState.loading;
    _lastEmittedPlaying = false;
    _setPlaybackState(
      updated.copyWith(
        controls: PlayerMediaControls.build(updated, isLiked: _isLiked()),
      ),
    );
  }
}

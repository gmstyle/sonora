import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:dart_cast/dart_cast.dart';
import 'playback_engine.dart';
import '../../../data/services/cast_service.dart';
import '../../../domain/models/queue_track.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';
import '../../providers/cast_provider.dart';
import 'playback_volume_controller.dart';

/// Owns Chromecast / remote-playback connection lifecycle and media casting.
///
/// Does not hold a back-reference to [SonoraAudioHandler]; playback intent is
/// injected via [requestPlay] (must call the handler's `play()`, not
/// `player.play()`, so the cast device stays in sync).
class CastPlaybackController {
  final PlaybackEngine _engine;
  final PlaybackVolumeController _volumeController;
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final bool Function() _userWantsPlaying;
  final MediaItem? Function() _currentMediaItem;
  final Future<void> Function() _requestPlay;

  CastState? _castState;
  SonoraCastService? _castService;
  bool pausedForConnection = false;
  int _castSongToken = 0;

  CastPlaybackController({
    required PlaybackEngine engine,
    required PlaybackVolumeController volumeController,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required bool Function() userWantsPlaying,
    required MediaItem? Function() currentMediaItem,
    required Future<void> Function() requestPlay,
  }) : _engine = engine,
       _volumeController = volumeController,
       _playVideoIdUseCase = playVideoIdUseCase,
       _userWantsPlaying = userWantsPlaying,
       _currentMediaItem = currentMediaItem,
       _requestPlay = requestPlay;

  CastState? get castState => _castState;
  SonoraCastService? get castService => _castService;

  Future<void> updateCastState(
    CastState state,
    SonoraCastService service,
  ) async {
    _castService = service;

    if (state.connectionState == CastConnectionState.connecting) {
      if (_engine.state.playing) {
        pausedForConnection = true;
        await _engine.pause();
      }
    } else if (state.connectionState == CastConnectionState.connected) {
      if (_castState?.connectionState != CastConnectionState.connected) {
        _volumeController.setLocalVolume(0.0);
        await castCurrentSong(state, service);
        pausedForConnection = false;
      }
    } else if (state.connectionState == CastConnectionState.disconnected ||
        state.connectionState == CastConnectionState.error) {
      if (_castState?.connectionState == CastConnectionState.connected) {
        _volumeController.setLocalVolume(
          _volumeController.lastSetVolume,
          force: true,
        );
      }
      if (pausedForConnection) {
        await _engine.play();
        pausedForConnection = false;
      }
    }

    _castState = state;
  }

  Future<void> castCurrentSong(
    CastState state,
    SonoraCastService service,
  ) async {
    final item = _currentMediaItem();
    if (item == null) return;
    final currentPos = _engine.state.position;
    await castSong(item, state, service, startPosition: currentPos);
  }

  Future<void> castSong(
    MediaItem item,
    CastState state,
    SonoraCastService service, {
    Duration? startPosition,
  }) async {
    // Grab a token so concurrent calls from rapid skips can be cancelled.
    final token = ++_castSongToken;

    final wasPlaying =
        _engine.state.playing || pausedForConnection || _userWantsPlaying();
    if (wasPlaying) {
      pausedForConnection = true;
      await _engine.pause();
    }
    _volumeController.setLocalVolume(0.0);

    // A newer castSong call has superseded this one — bail out.
    if (_castSongToken != token) return;

    final track = QueueTrack.fromMediaItem(item);
    String? url = track.hasUrl ? track.url : null;
    if (url == null || track.needsUrl) {
      try {
        url = await _playVideoIdUseCase.resolveUrl(track.videoId);
      } catch (_) {
        pausedForConnection = false;
        return;
      }
    }

    // Check again after the potentially slow URL resolve.
    if (_castSongToken != token) return;

    await service.castMedia(
      url: url,
      title: item.title,
      artist: item.artist,
      album: item.album,
      artworkUrl: item.artUri?.toString(),
      startPosition: startPosition,
    );

    if (wasPlaying) {
      await waitForCastSessionState(service, SessionState.playing);
      // Check after the wait — another skip could have fired during it.
      if (_castSongToken != token) return;
      pausedForConnection = false;
      // Use requestPlay (handler.play) so that castService?.play() is also
      // sent to the cast device.
      await _requestPlay();
    } else {
      await service.pause();
    }
  }

  Future<void> waitForCastSessionState(
    SonoraCastService service,
    SessionState targetState, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (service.activeSession?.state == targetState) return;
    final completer = Completer<void>();
    StreamSubscription? sub;
    sub = service.stateStream.listen((state) {
      if (state == targetState) {
        if (!completer.isCompleted) completer.complete();
        sub?.cancel();
      }
    });
    try {
      await completer.future.timeout(timeout);
    } catch (_) {
      // Timeout fallback
    } finally {
      await sub.cancel();
    }
  }
}

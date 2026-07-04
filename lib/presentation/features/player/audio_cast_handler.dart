import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:dart_cast/dart_cast.dart';
import 'audio_handler.dart';
import '../../../data/services/cast_service.dart';
import '../../providers/cast_provider.dart';

class AudioCastHandler {
  final SonoraAudioHandler _audioHandler;

  CastState? _castState;
  SonoraCastService? _castService;
  bool pausedForConnection = false;

  AudioCastHandler(this._audioHandler);

  CastState? get castState => _castState;
  SonoraCastService? get castService => _castService;

  Future<void> updateCastState(
    CastState state,
    SonoraCastService service,
  ) async {
    _castService = service;

    if (state.connectionState == CastConnectionState.connecting) {
      if (_audioHandler.player.state.playing) {
        pausedForConnection = true;
        await _audioHandler.player.pause();
      }
    } else if (state.connectionState == CastConnectionState.connected) {
      if (_castState?.connectionState != CastConnectionState.connected) {
        _audioHandler.setLocalVolume(0.0);
        await castCurrentSong(state, service);
        pausedForConnection = false;
      }
    } else if (state.connectionState == CastConnectionState.disconnected ||
        state.connectionState == CastConnectionState.error) {
      if (_castState?.connectionState == CastConnectionState.connected) {
        _audioHandler.setLocalVolume(
          _audioHandler.lastSetVolume * 100.0,
          force: true,
        );
      }
      if (pausedForConnection) {
        await _audioHandler.player.play();
        pausedForConnection = false;
      }
    }

    _castState = state;
  }

  Future<void> castCurrentSong(
    CastState state,
    SonoraCastService service,
  ) async {
    final item = _audioHandler.mediaItem.value;
    if (item == null) return;
    final currentPos = _audioHandler.player.state.position;
    await castSong(item, state, service, startPosition: currentPos);
  }

  Future<void> castSong(
    MediaItem item,
    CastState state,
    SonoraCastService service, {
    Duration? startPosition,
  }) async {
    final wasPlaying =
        _audioHandler.player.state.playing ||
        pausedForConnection ||
        _audioHandler.userWantsPlaying;
    if (wasPlaying) {
      pausedForConnection = true;
      await _audioHandler.player.pause();
    }
    _audioHandler.setLocalVolume(0.0);

    String? url = item.extras?['url'] as String?;
    if (url == null || url.isEmpty || item.extras?['needsUrl'] == true) {
      try {
        url = await _audioHandler.playVideoIdUseCase.resolveUrl(item.id);
      } catch (_) {
        pausedForConnection = false;
        return;
      }
    }

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
      pausedForConnection = false;
      await _audioHandler.player.play();
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

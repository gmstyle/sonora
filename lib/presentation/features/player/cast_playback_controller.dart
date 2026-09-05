import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:dart_cast/dart_cast.dart';
import 'playback_engine.dart';
import '../../../data/services/cast_service.dart';
import '../../../domain/models/queue_track.dart';
import '../../../domain/usecases/player/play_video_id_use_case.dart';
import '../../providers/cast_provider.dart';
import 'playback_volume_controller.dart';

bool _urlReachableByCastDevice(String? url) {
  if (url == null || url.isEmpty) return false;
  if (isPlaceholderAudioUri(url)) return false;
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;
  if (uri.scheme == 'file') return false;
  final host = uri.host;
  if (host == '127.0.0.1' || host == 'localhost' || host == '::1') {
    return false;
  }
  return uri.scheme == 'http' || uri.scheme == 'https';
}

/// Owns Chromecast / remote-playback connection lifecycle and media casting.
///
/// Does not hold a back-reference to [SonoraAudioHandler]; playback intent is
/// injected via [userWantsPlaying] / [currentMediaItem]. Local engine stays
/// paused while a cast session is active. Cast devices receive a LAN proxy
/// URL (not `file://` or loopback) so they can fetch audio from the phone.
class CastPlaybackController {
  final PlaybackEngine _engine;
  final PlaybackVolumeController _volumeController;
  final PlayVideoIdUseCase _playVideoIdUseCase;
  final bool Function() _userWantsPlaying;
  final MediaItem? Function() _currentMediaItem;
  final Future<String?> Function(QueueTrack track) _lanCastUrl;

  CastState? _castState;
  SonoraCastService? _castService;
  bool pausedForConnection = false;
  int _castSongToken = 0;
  int _castEpoch = 0;
  Duration? _lastCastPosition;
  SessionState? _remoteSessionState;
  StreamSubscription<Duration>? _castPositionSub;
  StreamSubscription<Duration>? _castDurationSub;
  StreamSubscription<SessionState>? _castSessionSub;

  void Function()? onTransportChanged;
  void Function(Duration position)? onCastPosition;
  void Function(Duration duration)? onCastDuration;

  CastPlaybackController({
    required PlaybackEngine engine,
    required PlaybackVolumeController volumeController,
    required PlayVideoIdUseCase playVideoIdUseCase,
    required bool Function() userWantsPlaying,
    required MediaItem? Function() currentMediaItem,
    required Future<String?> Function(QueueTrack track) lanCastUrl,
  }) : _engine = engine,
       _volumeController = volumeController,
       _playVideoIdUseCase = playVideoIdUseCase,
       _userWantsPlaying = userWantsPlaying,
       _currentMediaItem = currentMediaItem,
       _lanCastUrl = lanCastUrl;

  CastState? get castState => _castState;
  SonoraCastService? get castService => _castService;
  Duration? get lastCastPosition => _lastCastPosition;
  SessionState? get remoteSessionState => _remoteSessionState;

  bool get isRemotePlaying {
    if (_castState?.connectionState != CastConnectionState.connected) {
      return false;
    }
    return _remoteSessionState == SessionState.playing ||
        _remoteSessionState == SessionState.buffering;
  }

  Future<void> updateCastState(
    CastState state,
    SonoraCastService service,
  ) async {
    final previous = _castState;
    _castService = service;
    _castState = state;
    final epoch = ++_castEpoch;

    if (state.connectionState == CastConnectionState.connecting) {
      if (_engine.state.playing) {
        pausedForConnection = true;
        await _engine.pause();
      }
    } else if (state.connectionState == CastConnectionState.connected) {
      if (previous?.connectionState != CastConnectionState.connected) {
        _volumeController.setLocalVolume(0.0);
        _listenCastPosition(service);
        await castCurrentSong(state, service);
        if (epoch != _castEpoch) return;
      }
    } else if (state.connectionState == CastConnectionState.disconnected ||
        state.connectionState == CastConnectionState.error) {
      _stopCastPosition();
      final wasConnected =
          previous?.connectionState == CastConnectionState.connected;
      if (epoch != _castEpoch) return;
      if (wasConnected) {
        _volumeController.setLocalVolume(
          _volumeController.lastSetVolume,
          force: true,
        );
        final resumePos = _lastCastPosition;
        if (resumePos != null && resumePos > Duration.zero) {
          await _engine.seek(resumePos);
        }
      }
      if (pausedForConnection || _userWantsPlaying()) {
        if (!_engine.state.playing) await _engine.play();
        pausedForConnection = false;
      }
      _lastCastPosition = null;
    }
  }

  void _listenCastPosition(SonoraCastService service) {
    _castPositionSub?.cancel();
    _castDurationSub?.cancel();
    _castSessionSub?.cancel();
    _remoteSessionState = service.activeSession?.state;
    _castPositionSub = service.positionStream.listen((p) {
      _lastCastPosition = p;
      onCastPosition?.call(p);
    });
    _castDurationSub = service.durationStream.listen((d) {
      if (d > Duration.zero) {
        onCastDuration?.call(d);
      }
    });
    _castSessionSub = service.stateStream.listen((s) {
      _remoteSessionState = s;
      onTransportChanged?.call();
    });
  }

  void _stopCastPosition() {
    _castPositionSub?.cancel();
    _castPositionSub = null;
    _castDurationSub?.cancel();
    _castDurationSub = null;
    _castSessionSub?.cancel();
    _castSessionSub = null;
    _remoteSessionState = null;
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

    final epochAtStart = _castEpoch;

    final wasPlaying =
        _engine.state.playing || pausedForConnection || _userWantsPlaying();
    if (wasPlaying) {
      pausedForConnection = true;
      await _engine.pause();
    }
    _volumeController.setLocalVolume(0.0);
    _lastCastPosition = startPosition ?? Duration.zero;
    onCastPosition?.call(_lastCastPosition!);
    if (item.duration != null && item.duration! > Duration.zero) {
      onCastDuration?.call(item.duration!);
    }

    // A newer castSong call has superseded this one — bail out.
    if (_castSongToken != token || _castEpoch != epochAtStart) return;

    final track = QueueTrack.fromMediaItem(item);
    String? url = await _lanCastUrl(track);
    if (!_urlReachableByCastDevice(url) &&
        _urlReachableByCastDevice(track.url)) {
      url = track.url;
    }
    if (!_urlReachableByCastDevice(url)) {
      try {
        url = await _playVideoIdUseCase.resolveStreamUrl(track.videoId);
      } catch (_) {
        pausedForConnection = false;
        return;
      }
    }

    // Check again after the potentially slow URL resolve.
    if (_castSongToken != token || _castEpoch != epochAtStart) return;

    if (!_urlReachableByCastDevice(url)) {
      pausedForConnection = false;
      return;
    }

    await service.castMedia(
      url: url!,
      title: item.title,
      artist: item.artist,
      album: item.album,
      artworkUrl: item.artUri?.toString(),
      startPosition: startPosition,
    );

    if (_castSongToken != token || _castEpoch != epochAtStart) return;

    if (wasPlaying) {
      final reached = await waitForCastSessionState(
        service,
        SessionState.playing,
      );
      if (_castSongToken != token || _castEpoch != epochAtStart) return;
      if (reached) {
        _remoteSessionState = SessionState.playing;
      }
      await service.play();
      onTransportChanged?.call();
    } else {
      await service.pause();
      onTransportChanged?.call();
    }
  }

  Future<bool> waitForCastSessionState(
    SonoraCastService service,
    SessionState targetState, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (service.activeSession?.state == targetState) return true;
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
      return true;
    } catch (_) {
      return false;
    } finally {
      await sub.cancel();
    }
  }
}

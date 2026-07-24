import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';

import '../../domain/models/queue_track.dart';
import 'player_provider.dart';

class VideoPlayerState {
  final VideoController? controller;
  final bool isVideoVisible;
  final bool isInitialized;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final String? currentVideoUrl;
  final int videoWidth;
  final int videoHeight;

  const VideoPlayerState({
    this.controller,
    this.isVideoVisible = true,
    this.isInitialized = false,
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage,
    this.currentVideoUrl,
    this.videoWidth = 16,
    this.videoHeight = 9,
  });

  double get aspectRatio =>
      videoWidth > 0 && videoHeight > 0 ? videoWidth / videoHeight : 16 / 9;

  VideoPlayerState copyWith({
    VideoController? controller,
    bool? isVideoVisible,
    bool? isInitialized,
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    String? currentVideoUrl,
    int? videoWidth,
    int? videoHeight,
  }) {
    return VideoPlayerState(
      controller: controller ?? this.controller,
      isVideoVisible: isVideoVisible ?? this.isVideoVisible,
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      currentVideoUrl: currentVideoUrl ?? this.currentVideoUrl,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
    );
  }
}

class VideoPlayerNotifier extends Notifier<VideoPlayerState> {
  Player get _player => ref.read(audioHandlerProvider).player;
  StreamSubscription<VideoParams>? _videoParamsSub;
  String? _lastVideoId;
  ProviderSubscription<PlayerState>? _playbackSub;
  VideoController? _controller;

  @override
  VideoPlayerState build() {
    _playbackSub = ref.listen(playerStateProvider, (prev, next) {
      _onPlayerStateChanged(next);
    });

    ref.onDispose(() {
      _playbackSub?.close();
      _videoParamsSub?.cancel();
      _controller = null;
    });

    final initialPlayerState = ref.read(playerStateProvider);
    if (initialPlayerState.isVideo) {
      Future.microtask(() {
        _onPlayerStateChanged(ref.read(playerStateProvider));
      });
    }

    return const VideoPlayerState();
  }

  void _ensureInitialized() {
    if (_controller != null) {
      if (!state.isInitialized) {
        state = state.copyWith(controller: _controller, isInitialized: true);
      }
      return;
    }
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    state = state.copyWith(controller: _controller, isInitialized: true);
  }

  void _onPlayerStateChanged(PlayerState next) {
    final isVideo = next.isVideo;
    final currentSong = next.currentSong;

    if (!isVideo) {
      if (_lastVideoId != null) {
        _lastVideoId = null;
        _videoParamsSub?.cancel();
        _videoParamsSub = null;
        _player.setVideoTrack(VideoTrack.no());
        state = state.copyWith(
          isInitialized: false,
          isLoading: false,
          currentVideoUrl: null,
        );
      }
      return;
    }

    _ensureInitialized();

    final videoId = currentSong?.id;
    final videoChanged = videoId != _lastVideoId;
    final loadingChanged = next.isLoading != state.isLoading;
    final finishedLoading = !next.isLoading && state.isLoading;

    if (videoChanged || loadingChanged) {
      _lastVideoId = videoId;
      final url =
          currentSong != null
              ? QueueTrack.fromMediaItem(currentSong).url
              : null;

      state = state.copyWith(
        isLoading: next.isLoading,
        currentVideoUrl: url,
        videoWidth: 16,
        videoHeight: 9,
      );

      _videoParamsSub?.cancel();
      _videoParamsSub = _player.stream.videoParams.listen((params) {
        final w = params.dw ?? params.w ?? 16;
        final h = params.dh ?? params.h ?? 9;
        if (w > 0 && h > 0) {
          state = state.copyWith(videoWidth: w, videoHeight: h);
        }
      });

      if (videoId != null && (videoChanged || finishedLoading)) {
        _updateVideoTrack(forceKick: finishedLoading);
      }
    }
  }

  void _updateVideoTrack({bool forceKick = false}) {
    final currentVideoTrack = _player.state.track.video;
    final isNone = currentVideoTrack.id == 'no';

    if (state.isVideoVisible && _lastVideoId != null) {
      if (isNone || (Platform.isLinux && forceKick)) {
        // On Linux, a rapid toggle from no to auto often kicks the VO into
        // correctly attaching the texture when the initial open/restore
        // left it black.
        if (Platform.isLinux) {
          _player.setVideoTrack(VideoTrack.no());
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (state.isVideoVisible && _lastVideoId != null) {
              _player.setVideoTrack(VideoTrack.auto());

              // Force a redraw if paused by nudging the position with a double-seek.
              // This is an aggressive strategy to ensure mpv pushes a frame to the
              // Flutter texture even when paused.
              if (!_player.state.playing) {
                final currentPos = _player.state.position;
                _player.seek(currentPos + const Duration(milliseconds: 1));
                Future.delayed(const Duration(milliseconds: 50), () {
                  _player.seek(currentPos);
                });
              }

              dev.log(
                '[VideoPlayerNotifier] Linux Frame Force: setVideoTrack(auto) (force=$forceKick)',
              );
            }
          });
        } else {
          _player.setVideoTrack(VideoTrack.auto());
          dev.log('[VideoPlayerNotifier] setVideoTrack(auto)');
        }
      }
    } else {
      if (!isNone) {
        _player.setVideoTrack(VideoTrack.no());
        dev.log('[VideoPlayerNotifier] setVideoTrack(no)');
      }
    }
  }

  void toggleVisibility() {
    state = state.copyWith(isVideoVisible: !state.isVideoVisible);
    _updateVideoTrack();
  }
}

final videoPlayerProvider =
    NotifierProvider<VideoPlayerNotifier, VideoPlayerState>(
      VideoPlayerNotifier.new,
    );

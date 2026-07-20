import 'dart:async';
import 'dart:developer' as dev;

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

class VideoPlayerNotifier extends Notifier<VideoPlayerState>
    with WidgetsBindingObserver {
  Player get _player => ref.read(audioHandlerProvider).player;
  StreamSubscription<VideoParams>? _videoParamsSub;
  String? _lastVideoId;
  ProviderSubscription<PlayerState>? _playbackSub;
  VideoController? _controller;

  @override
  VideoPlayerState build() {
    WidgetsBinding.instance.addObserver(this);

    _playbackSub = ref.listen(playerStateProvider, (prev, next) {
      _onPlayerStateChanged(next);
    });

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      try {
        _player.setVideoTrack(VideoTrack.no());
        _setVideoDecoding(false);
        dev.log(
          '[VideoPlayerNotifier] App in background: disabled video tracking/decoding',
        );
      } catch (e) {
        dev.log(
          '[VideoPlayerNotifier] Failed to disable video in background: $e',
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      dev.log(
        '[VideoPlayerNotifier] App resumed: restoring video tracking/decoding if needed',
      );
      _onPlayerStateChanged(ref.read(playerStateProvider));
    }
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
      configuration: VideoControllerConfiguration(
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
        _setVideoDecoding(false);
        state = state.copyWith(
          isInitialized: false,
          isLoading: false,
          currentVideoUrl: null,
        );
      }
      return;
    }

    _ensureInitialized();
    _setVideoDecoding(true);

    final videoId = currentSong?.id;
    if (videoId != _lastVideoId) {
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
    } else {
      state = state.copyWith(isLoading: next.isLoading);
    }

    _updateVideoTrack();
  }

  void _updateVideoTrack() {
    if (state.isVideoVisible && _lastVideoId != null) {
      _player.setVideoTrack(VideoTrack.auto());
    } else {
      _player.setVideoTrack(VideoTrack.no());
    }
  }

  /// Toggle mpv video decoding subsystem.
  /// When disabled (`video=no`), mpv won't allocate video decoding resources,
  /// preventing crashes when Android destroys the rendering surface in background.
  void _setVideoDecoding(bool enabled) {
    try {
      final platform = _player.platform;
      if (platform is NativePlayer) {
        platform.setProperty('video', enabled ? 'auto' : 'no');
      }
    } catch (e) {
      dev.log('[VideoPlayerNotifier] Failed to set video decoding: $e');
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

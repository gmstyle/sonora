import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';

import '../../domain/models/queue_track.dart';
import 'player_provider.dart';
import 'settings_provider.dart';

bool shouldShowVideoPlayer({
  required bool enableVideoPlayback,
  required VideoPlayerState videoState,
}) =>
    enableVideoPlayback &&
    videoState.isVideoVisible &&
    videoState.isInitialized;

/// Shimmer only before the first [VideoController]. After that, keep the
/// surface mounted so track switches do not duplicate the Video [GlobalKey]
/// inside [AnimatedSwitcher].
bool shouldReplaceVideoWithShimmer(VideoPlayerState videoState) =>
    videoState.isLoading && !videoState.isInitialized;

/// Whether a [VideoController] (and Android texture) should be allocated.
bool shouldAttachVideoController({
  required bool enableVideoPlayback,
  required bool isVideoTrack,
}) => enableVideoPlayback && isVideoTrack;

/// Whether the soft background detach (`setVideoTrack(no)`) should run.
bool shouldDetachVideoOnBackground({
  required bool isAndroid,
  required bool enableVideoPlayback,
  required bool hasActiveVideoSession,
}) => isAndroid && enableVideoPlayback && hasActiveVideoSession;

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
    this.isVideoVisible = false,
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
    bool clearController = false,
    bool clearCurrentVideoUrl = false,
  }) {
    return VideoPlayerState(
      controller: clearController ? null : (controller ?? this.controller),
      isVideoVisible: isVideoVisible ?? this.isVideoVisible,
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      currentVideoUrl:
          clearCurrentVideoUrl
              ? null
              : (currentVideoUrl ?? this.currentVideoUrl),
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

    ref.listen(playerStateProvider.select((s) => s.isRestoring), (prev, next) {
      if (prev == true && next == false) {
        final playerState = ref.read(playerStateProvider);
        if (playerState.isVideo) {
          _updateVideoTrack(forceKick: true);
        }
      }
    });

    ref.listen(settingsProvider.select((s) => s.enableVideoPlayback), (
      prev,
      next,
    ) {
      if (next && prev == false) {
        state = state.copyWith(isVideoVisible: true);
        _onPlayerStateChanged(ref.read(playerStateProvider));
      } else if (!next) {
        try {
          _player.setVideoTrack(VideoTrack.no());
        } catch (_) {}
        _disposeController();
      } else {
        _updateVideoTrack();
      }
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
    if (!Platform.isAndroid) return;

    final enableVideoPlayback = ref.read(settingsProvider).enableVideoPlayback;
    final hasActiveVideoSession = _lastVideoId != null;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!shouldDetachVideoOnBackground(
        isAndroid: true,
        enableVideoPlayback: enableVideoPlayback,
        hasActiveVideoSession: hasActiveVideoSession,
      )) {
        return;
      }
      try {
        _player.setVideoTrack(VideoTrack.no());
        dev.log(
          '[VideoPlayerNotifier] App in background: soft-detached video track',
        );
      } catch (e) {
        dev.log(
          '[VideoPlayerNotifier] Failed to soft-detach video in background: $e',
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      if (enableVideoPlayback && hasActiveVideoSession) {
        dev.log(
          '[VideoPlayerNotifier] App resumed: restoring video track if needed',
        );
        _updateVideoTrack(forceKick: true);
      }
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
      configuration: const VideoControllerConfiguration(
        androidAttachSurfaceAfterVideoParameters: false,
      ),
    );
    state = state.copyWith(controller: _controller, isInitialized: true);
  }

  /// Releases the [VideoController] so Android can drop the texture / ImageReader.
  void _disposeController() {
    _videoParamsSub?.cancel();
    _videoParamsSub = null;
    _lastVideoId = null;
    _controller = null;
    state = state.copyWith(
      clearController: true,
      isInitialized: false,
      isLoading: false,
      clearCurrentVideoUrl: true,
    );
  }

  void _onPlayerStateChanged(PlayerState next) {
    final isVideo = next.isVideo;
    final currentSong = next.currentSong;
    final enableVideoPlayback = ref.read(settingsProvider).enableVideoPlayback;

    if (!isVideo) {
      if (_lastVideoId != null || _controller != null) {
        try {
          _player.setVideoTrack(VideoTrack.no());
        } catch (_) {}
        _disposeController();
      }
      return;
    }

    if (!shouldAttachVideoController(
      enableVideoPlayback: enableVideoPlayback,
      isVideoTrack: true,
    )) {
      try {
        _player.setVideoTrack(VideoTrack.no());
      } catch (_) {}
      if (_controller != null) {
        _disposeController();
      }
      return;
    }

    _ensureInitialized();

    final videoId = currentSong?.id;
    final videoChanged = videoId != _lastVideoId;
    final loadingChanged = next.isLoading != state.isLoading;
    final finishedLoading = !next.isLoading && state.isLoading;

    // HLS (and progressive streams) toggle buffering often. Only reset
    // geometry / force-kick the video track when the video id actually
    // changes — otherwise every buffer event blanked the Linux surface
    // for ~1s via setVideoTrack(no)→auto.
    if (videoChanged) {
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

      if (videoId != null) {
        _updateVideoTrack(forceKick: true);
      }
      return;
    }

    if (loadingChanged) {
      state = state.copyWith(isLoading: next.isLoading);
      // Soft restore only: if the track is stuck on "no", turn it back on.
      // Never forceKick on buffering end — that caused the stutter loop.
      if (finishedLoading && videoId != null) {
        _updateVideoTrack(forceKick: false);
      }
    }
  }

  void _updateVideoTrack({bool forceKick = false}) {
    final currentVideoTrack = _player.state.track.video;
    final isNone = currentVideoTrack.id == 'no';
    final enableVideoPlayback = ref.read(
      settingsProvider.select((s) => s.enableVideoPlayback),
    );

    if (enableVideoPlayback && state.isVideoVisible && _lastVideoId != null) {
      if (isNone || forceKick) {
        // Toggle no → auto so the VO re-attaches a frame on track change /
        // restore. Linux needs a longer delay; other platforms kick faster.
        _player.setVideoTrack(VideoTrack.no());
        final delay =
            Platform.isLinux
                ? const Duration(milliseconds: 1000)
                : const Duration(milliseconds: 50);
        Future.delayed(delay, () {
          if (ref.read(settingsProvider).enableVideoPlayback &&
              state.isVideoVisible &&
              _lastVideoId != null) {
            _player.setVideoTrack(VideoTrack.auto());

            // Force a redraw if paused by nudging the position with a double-seek
            // so mpv pushes a frame to the Flutter texture.
            if (!_player.state.playing) {
              final currentPos = _player.state.position;
              _player.seek(currentPos + const Duration(milliseconds: 1));
              Future.delayed(const Duration(milliseconds: 50), () {
                _player.seek(currentPos);
              });
            }

            dev.log(
              '[VideoPlayerNotifier] setVideoTrack(auto) (force=$forceKick)',
            );
          }
        });
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

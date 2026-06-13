import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';

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
  // M1: Lazy-init — Player created only when first video is played
  Player? _player;
  VideoController? _controller;
  bool _playerInitialized = false;

  ProviderSubscription<PlayerState>? _playbackSub;
  StreamSubscription<Duration>? _videoPositionSub;
  StreamSubscription<VideoParams>? _videoParamsSub;
  String? _loadedUrl;
  DateTime _lastVideoSeekTime = DateTime(0);

  // M5: Race condition guard
  int _loadingGeneration = 0;

  @override
  VideoPlayerState build() {
    _playbackSub = ref.listen(playerStateProvider, (prev, next) {
      _onPlayerStateChanged(next);
    });

    ref.onDispose(() {
      _playbackSub?.close();
      _videoPositionSub?.cancel();
      _videoParamsSub?.cancel();
      // M6: stop before dispose
      _player?.stop().then((_) => _player?.dispose());
    });

    return const VideoPlayerState();
  }

  /// M1: Ensure player is created (lazy-init)
  void _ensurePlayer() {
    if (_playerInitialized) return;
    _playerInitialized = true;
    _player = Player(configuration: const PlayerConfiguration(muted: true));
    _controller = VideoController(_player!);
    state = state.copyWith(controller: _controller);
  }

  void _onPlayerStateChanged(PlayerState next) {
    final currentSong = next.currentSong;
    final isVideo = next.isVideo;

    if (!isVideo) {
      if (_loadedUrl != null) {
        _videoPositionSub?.cancel();
        _videoPositionSub = null;
        _videoParamsSub?.cancel();
        _videoParamsSub = null;
        _player?.stop();
        _loadedUrl = null;
        state = state.copyWith(
          isInitialized: false,
          isLoading: false,
          currentVideoUrl: null,
        );
      }
      return;
    }

    final url = currentSong?.extras?['url'] as String?;
    if (url == null || url.isEmpty) return;

    if (url != _loadedUrl) {
      _loadedUrl = url;
      _loadVideo(url, initialPosition: next.position);
    }

    if (_player != null) {
      if (next.isPlaying) {
        _player!.play();
      } else {
        _player!.pause();
      }
    }

    // Sync video seek with audio seek (H1)
    if (state.isInitialized && _player != null) {
      final videoPos = _player!.state.position;
      final audioPos = next.position;
      final drift = (audioPos - videoPos).abs();
      final now = DateTime.now();
      if (drift > const Duration(milliseconds: 500) &&
          now.difference(_lastVideoSeekTime) > const Duration(seconds: 1)) {
        _lastVideoSeekTime = now;
        _player!.seek(audioPos);
      }
    }
  }

  Future<void> _loadVideo(
    String url, {
    Duration initialPosition = Duration.zero,
  }) async {
    // M5: Increment generation counter
    final generation = ++_loadingGeneration;

    _ensurePlayer();

    state = state.copyWith(
      isLoading: true,
      hasError: false,
      errorMessage: null,
    );

    try {
      _videoPositionSub?.cancel();
      _videoParamsSub?.cancel();
      await _player!.open(Media(url), play: false);

      // M5: Check if a newer load has started
      if (generation != _loadingGeneration) return;

      // H2: Seek to current audio position after open
      if (initialPosition > Duration.zero) {
        await _player!.seek(initialPosition);
      }

      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        currentVideoUrl: url,
      );

      // L1: Listen to video dimensions for dynamic aspect ratio
      _videoParamsSub = _player!.stream.videoParams.listen((params) {
        final w = params.dw ?? params.w ?? 16;
        final h = params.dh ?? params.h ?? 9;
        if (w > 0 && h > 0) {
          state = state.copyWith(videoWidth: w, videoHeight: h);
        }
      });

      // Listen to video position to detect user-initiated audio seeks
      _videoPositionSub = _player!.stream.position.listen((videoPos) {
        final audioState = ref.read(playerStateProvider);
        if (!audioState.isVideo) return;
        final drift = (audioState.position - videoPos).abs();
        final now = DateTime.now();
        if (drift > const Duration(milliseconds: 500) &&
            now.difference(_lastVideoSeekTime) > const Duration(seconds: 1)) {
          _lastVideoSeekTime = now;
          _player!.seek(audioState.position);
        }
      });
    } catch (e) {
      // M2: Log error in debug mode
      if (kDebugMode) {
        debugPrint('VideoPlayer: failed to load $url: $e');
      }
      // M5: Only update state if this load is still current
      if (generation == _loadingGeneration) {
        state = state.copyWith(
          isInitialized: false,
          isLoading: false,
          hasError: true,
          errorMessage: e.toString(),
        );
      }
    }
  }

  void toggleVisibility() {
    state = state.copyWith(isVideoVisible: !state.isVideoVisible);
  }
}

// M7: Keeping NotifierProvider (not AutoDispose) because the video Player
// must persist across navigation pushes. AutoDispose would destroy the
// native player when the full player screen is popped during a mini→full
// transition, causing a black screen on re-entry.
final videoPlayerProvider =
    NotifierProvider<VideoPlayerNotifier, VideoPlayerState>(
      VideoPlayerNotifier.new,
    );

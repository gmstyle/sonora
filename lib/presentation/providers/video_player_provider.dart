import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' hide PlayerState;
import 'package:media_kit_video/media_kit_video.dart';

import 'player_provider.dart';

class VideoPlayerState {
  final VideoController controller;
  final bool isVideoVisible;
  final bool isInitialized;
  final String? currentVideoUrl;

  const VideoPlayerState({
    required this.controller,
    this.isVideoVisible = true,
    this.isInitialized = false,
    this.currentVideoUrl,
  });

  VideoPlayerState copyWith({
    bool? isVideoVisible,
    bool? isInitialized,
    String? currentVideoUrl,
  }) {
    return VideoPlayerState(
      controller: controller,
      isVideoVisible: isVideoVisible ?? this.isVideoVisible,
      isInitialized: isInitialized ?? this.isInitialized,
      currentVideoUrl: currentVideoUrl ?? this.currentVideoUrl,
    );
  }
}

class VideoPlayerNotifier extends Notifier<VideoPlayerState> {
  late final Player _player;
  ProviderSubscription<PlayerState>? _playbackSub;
  String? _loadedUrl;

  @override
  VideoPlayerState build() {
    _player = Player(configuration: const PlayerConfiguration(muted: true));
    final controller = VideoController(_player);

    _playbackSub = ref.listen(playerStateProvider, (prev, next) {
      _onPlayerStateChanged(next);
    });

    ref.onDispose(() {
      _playbackSub?.close();
      _player.dispose();
    });

    return VideoPlayerState(controller: controller);
  }

  void _onPlayerStateChanged(PlayerState next) {
    final currentSong = next.currentSong;
    final isVideo = next.isVideo;

    if (!isVideo) {
      if (_loadedUrl != null) {
        _player.stop();
        _loadedUrl = null;
        state = state.copyWith(isInitialized: false, currentVideoUrl: null);
      }
      return;
    }

    final url = currentSong?.extras?['url'] as String?;
    if (url == null || url.isEmpty) return;

    if (url != _loadedUrl) {
      _loadedUrl = url;
      _loadVideo(url);
    }

    if (next.isPlaying) {
      _player.play();
    } else {
      _player.pause();
    }
  }

  Future<void> _loadVideo(String url) async {
    try {
      await _player.open(Media(url), play: false);
      state = state.copyWith(isInitialized: true, currentVideoUrl: url);
    } catch (_) {
      state = state.copyWith(isInitialized: false);
    }
  }

  void toggleVisibility() {
    state = state.copyWith(isVideoVisible: !state.isVideoVisible);
  }
}

final videoPlayerProvider =
    NotifierProvider<VideoPlayerNotifier, VideoPlayerState>(
      VideoPlayerNotifier.new,
    );

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../providers/video_player_provider.dart';
import '../../../providers/player_provider.dart';

class SonoraVideoPlayer extends ConsumerStatefulWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final Widget? placeholder;
  final bool showControls;
  final bool autoFullscreenOnLandscape;

  const SonoraVideoPlayer({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.placeholder,
    this.showControls = true,
    this.autoFullscreenOnLandscape = false,
  });

  @override
  ConsumerState<SonoraVideoPlayer> createState() => _SonoraVideoPlayerState();
}

class _SonoraVideoPlayerState extends ConsumerState<SonoraVideoPlayer>
    with WidgetsBindingObserver {
  final GlobalKey<VideoState> _videoKey = GlobalKey<VideoState>();
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lastOrientation ??= MediaQuery.of(context).orientation;
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!widget.autoFullscreenOnLandscape ||
        !(Platform.isAndroid || Platform.isIOS)) {
      return;
    }

    final size = View.of(context).physicalSize;
    if (size.width == 0 || size.height == 0) return;

    final orientation =
        size.width > size.height ? Orientation.landscape : Orientation.portrait;

    if (_lastOrientation != null && _lastOrientation != orientation) {
      _lastOrientation = orientation;
      if (orientation == Orientation.landscape) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _videoKey.currentState?.enterFullscreen();
          }
        });
      } else if (orientation == Orientation.portrait) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && (_videoKey.currentState?.isFullscreen() ?? false)) {
            _videoKey.currentState?.exitFullscreen();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoPlayerProvider);
    final cs = Theme.of(context).colorScheme;

    // Listen to player state to exit fullscreen if current track is no longer a video
    ref.listen(playerStateProvider, (prev, next) {
      if (prev?.isVideo == true && next.isVideo == false) {
        if (_videoKey.currentState?.isFullscreen() ?? false) {
          _videoKey.currentState?.exitFullscreen();
        }
      }
    });

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildContent(context, videoState, cs),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    VideoPlayerState videoState,
    ColorScheme cs,
  ) {
    // M4: Show shimmer while video is loading
    if (videoState.isLoading) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Shimmer.fromColors(
        key: const ValueKey('loading'),
        baseColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE0E0E0),
        highlightColor:
            isDark ? const Color(0xFF48484A) : const Color(0xFFF5F5F5),
        child: Container(color: Colors.white),
      );
    }

    // M3: Show error state
    if (videoState.hasError) {
      return Container(
        key: const ValueKey('error'),
        color: cs.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.videocam_off,
            color: cs.onSurfaceVariant.withAlpha(128),
            size: 32,
          ),
        ),
      );
    }

    // Show video when initialized
    if (videoState.isInitialized && videoState.controller != null) {
      final videoWidget = Video(
        key: _videoKey,
        controller: videoState.controller!,
        fit: widget.fit,
        controls: widget.showControls ? MaterialVideoControls : NoVideoControls,
        pauseUponEnteringBackgroundMode: false,
        resumeUponEnteringForegroundMode: false,
        onEnterFullscreen: () async {
          await SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.immersiveSticky,
            overlays: [],
          );
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        },
        onExitFullscreen: () async {
          await SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: SystemUiOverlay.values,
          );
          await SystemChrome.setPreferredOrientations([]);
        },
      );

      if (!widget.showControls) {
        return AspectRatio(
          aspectRatio: videoState.aspectRatio,
          child: videoWidget,
        );
      }

      return MaterialVideoControlsTheme(
        normal: MaterialVideoControlsThemeData(
          buttonBarButtonSize: 24.0,
          buttonBarHeight: 48.0,
          primaryButtonBar: [],
          bottomButtonBar: [
            const Spacer(),
            MaterialCustomButton(
              onPressed: () => _videoKey.currentState?.enterFullscreen(),
              icon: const Icon(
                LucideIcons.maximize,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
        fullscreen: MaterialVideoControlsThemeData(
          primaryButtonBar: [
            const Spacer(),
            MaterialCustomButton(
              onPressed: () {
                ref.read(playerStateProvider.notifier).skipToPrevious();
              },
              icon: const Icon(LucideIcons.skipBack, color: Colors.white),
            ),
            const MaterialPlayOrPauseButton(
              iconSize: 48,
              iconColor: Colors.white,
            ),
            MaterialCustomButton(
              onPressed: () {
                ref.read(playerStateProvider.notifier).skipToNext();
              },
              icon: const Icon(LucideIcons.skipForward, color: Colors.white),
            ),
            const Spacer(),
          ],
          bottomButtonBar: [
            const MaterialPositionIndicator(
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            const Spacer(),
            const MaterialFullscreenButton(iconColor: Colors.white),
          ],
        ),
        child: AspectRatio(
          aspectRatio: videoState.aspectRatio,
          child: videoWidget,
        ),
      );
    }

    // Default placeholder
    return widget.placeholder ??
        Container(
          key: const ValueKey('placeholder'),
          color: cs.surfaceContainerHighest,
        );
  }
}

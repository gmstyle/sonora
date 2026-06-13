import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shimmer/shimmer.dart';

import '../../../providers/video_player_provider.dart';

class SonoraVideoPlayer extends ConsumerWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final String tag;
  final Widget? placeholder;

  const SonoraVideoPlayer({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.tag = 'default',
    this.placeholder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoPlayerProvider);
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
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
      return Video(
        key: ValueKey('video_$tag'),
        controller: videoState.controller!,
        fit: fit,
        controls: NoVideoControls,
      );
    }

    // Default placeholder
    return placeholder ??
        Container(
          key: const ValueKey('placeholder'),
          color: cs.surfaceContainerHighest,
        );
  }
}

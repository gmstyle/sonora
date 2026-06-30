import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../providers/palette_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/video_player_provider.dart';
import 'player_shared_widgets.dart';
import 'video_player_widget.dart';

class Artwork extends ConsumerWidget {
  const Artwork({
    super.key,
    required this.artUrl,
    required this.size,
    required this.videoId,
    this.isSwitching = false,
    this.isVideo = false,
    this.showFlipIndicator = false,
  });

  final String? artUrl;
  final double size;
  final String videoId;
  final bool isSwitching;
  final bool isVideo;
  final bool showFlipIndicator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoPlayerProvider);
    if (isVideo && videoState.isVideoVisible && videoState.isInitialized) {
      return SonoraVideoPlayer(
        width: size,
        height: size / videoState.aspectRatio,
        borderRadius: BorderRadius.circular(12),
      );
    }
    final paletteMap = ref.watch(paletteNotifierProvider);
    final paletteData = paletteMap[videoId];
    final dominantColor =
        paletteData?.dominantColor ??
        Theme.of(context).colorScheme.primaryContainer;
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    final clampedSize = size.clamp(150.0, 600.0);
    final artworkWidget = buildArtwork(
      context,
      artUrl,
      isSwitching,
      size,
      dominantColor,
      reduceEffects: reduceEffects,
    );

    return SizedBox(
      width: clampedSize,
      height: clampedSize,
      child: Stack(
        children: [
          Positioned.fill(child: artworkWidget),
          if (showFlipIndicator)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                child: Icon(
                  LucideIcons.barChart2,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

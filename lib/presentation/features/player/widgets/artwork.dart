import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../providers/palette_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/video_player_provider.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/vinyl_artwork.dart';
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
      final double videoWidth;
      final double videoHeight;
      if (videoState.aspectRatio > 1.0) {
        videoWidth = size;
        videoHeight = size / videoState.aspectRatio;
      } else {
        videoHeight = size;
        videoWidth = size * videoState.aspectRatio;
      }
      return SonoraVideoPlayer(
        width: videoWidth,
        height: videoHeight,
        borderRadius: BorderRadius.circular(12),
        autoFullscreenOnLandscape: true,
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
    final useVinylStyle = ref.watch(
      settingsProvider.select((s) => s.useVinylStyle),
    );
    final isPlaying = ref.watch(playerStateProvider.select((s) => s.isPlaying));
    final clampedSize = size.clamp(150.0, 600.0);

    final artworkWidget =
        useVinylStyle
            ? Container(
              width: clampedSize,
              height: clampedSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  if (!reduceEffects)
                    BoxShadow(
                      color: dominantColor.withValues(alpha: 0.55),
                      blurRadius: 32,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                ],
              ),
              child:
                  isSwitching
                      ? ClipOval(
                        child: SizedBox(
                          width: clampedSize,
                          height: clampedSize,
                          child: const ShimmerLoading(
                            variant: ShimmerVariant.artworkLarge,
                          ),
                        ),
                      )
                      : VinylArtwork(
                        imageUrl: artUrl,
                        size: clampedSize,
                        isPlaying: isPlaying,
                        useShadow: false,
                      ),
            )
            : buildArtwork(
              context,
              artUrl,
              isSwitching,
              size,
              dominantColor,
              reduceEffects: reduceEffects,
            );

    return Center(
      child: AspectRatio(
        aspectRatio: 1.0,
        child: SizedBox(
          width: clampedSize,
          height: clampedSize,
          child: Stack(
            children: [
              Positioned.fill(child: artworkWidget),
              if (showFlipIndicator)
                Positioned(
                  top: useVinylStyle ? 24 : 12,
                  right: useVinylStyle ? 24 : 12,
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
        ),
      ),
    );
  }
}

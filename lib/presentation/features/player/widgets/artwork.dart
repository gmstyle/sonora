import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/sonora_pulse_tokens.dart';
import '../../../../domain/models/artwork_style.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../providers/palette_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/styled_artwork.dart';
import 'player_shared_widgets.dart';

class Artwork extends ConsumerWidget {
  const Artwork({
    super.key,
    required this.artUrl,
    required this.size,
    required this.videoId,
    this.isSwitching = false,
    this.showFlipIndicator = false,
    this.minSize = 150,
  });

  final String? artUrl;
  final double size;
  final String videoId;
  final bool isSwitching;
  final bool showFlipIndicator;

  /// Lower bound for [size]. The full-player header uses a value under 150.
  final double minSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paletteMap = ref.watch(paletteNotifierProvider);
    final paletteData = paletteMap[videoId];
    final dominantColor =
        paletteData?.dominantColor ??
        Theme.of(context).colorScheme.primaryContainer;
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    final current = ref.watch(playerStateProvider.select((s) => s.currentSong));
    final isEpisode =
        current != null && QueueTrack.fromMediaItem(current).isEpisode;
    final style = ref
        .watch(settingsProvider.select((s) => s.artworkStyle))
        .forPlayback(isEpisode: isEpisode);
    final isPlaying = ref.watch(playerStateProvider.select((s) => s.isPlaying));
    final clampedSize = size.clamp(minSize, 600.0);
    final circular = style != ArtworkStyle.bars && style != ArtworkStyle.plain;

    final artworkWidget = style == ArtworkStyle.plain
        ? buildArtwork(
            context,
            artUrl,
            isSwitching,
            size,
            dominantColor,
            reduceEffects: reduceEffects,
          )
        : Container(
            width: clampedSize,
            height: clampedSize,
            decoration: BoxDecoration(
              shape: circular ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: circular
                  ? null
                  : BorderRadius.circular(SonoraPulseTokens.radiusMedia),
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
            child: isSwitching
                ? _StageShimmer(style: style, size: clampedSize)
                : buildStyledPlayerArt(
                    style: style,
                    imageUrl: artUrl,
                    size: clampedSize,
                    isPlaying: isPlaying,
                    mini: false,
                  ),
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
                  top: circular ? 24 : 12,
                  right: circular ? 24 : 12,
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

class _StageShimmer extends StatelessWidget {
  const _StageShimmer({required this.style, required this.size});

  final ArtworkStyle style;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shimmer = SizedBox.square(
      dimension: size,
      child: const ShimmerLoading(variant: ShimmerVariant.artworkLarge),
    );
    if (style == ArtworkStyle.bars) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(SonoraPulseTokens.radiusMedia),
        child: shimmer,
      );
    }
    return ClipOval(child: shimmer);
  }
}

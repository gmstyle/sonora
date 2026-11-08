import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/sonora_pulse_tokens.dart';
import '../../../domain/models/queue_track.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../shared/widgets/explicit_badge.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/vinyl_artwork.dart';
import 'full_player_content.dart';
import 'widgets/animated_play_pause_icon.dart';
import 'widgets/player_shared_widgets.dart';
import 'widgets/progress_bar_widget.dart';

/// Floating mobile mini player that sits above [MobileShell]'s navigation bar.
///
/// Light uses the white canvas at 95% with blur. Dark uses
/// [ColorScheme.surfaceContainerLow] at 95% and the indigo
/// [SonoraPulseTokens.darkBorder]. The 2px brand gradient is the seek strip.
/// Like and the gradient play control sit on the right. Swipe left or right
/// skips; swipe up or tap opens [FullPlayerContent].
class PlayerSheetMobile extends ConsumerWidget {
  const PlayerSheetMobile({super.key});

  /// Card height. Artwork is 44, with 8 of padding above and below.
  static const double height = 60;

  /// Gap between this card and the navigation bar.
  static const double dockGap = 8;

  /// Space the shell reserves under page content while the card is showing.
  static const double reservedHeight = height + dockGap;

  static const double _artSize = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final currentSong = playerState.currentSong;
    if (currentSong == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final playerNotifier = ref.read(playerStateProvider.notifier);
    final isPlaying = ref.watch(playerStateProvider.select((s) => s.isPlaying));
    final isSwitching = playerState.isBlocked;
    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    final track = QueueTrack.fromMediaItem(currentSong);
    final artUrl = currentSong.artUri?.toString();
    final useVinylStyle =
        ref.watch(settingsProvider.select((s) => s.useVinylStyle)) &&
        !track.isEpisode;

    final radius = BorderRadius.circular(SonoraPulseTokens.radiusMedia);
    final isDark = cs.brightness == Brightness.dark;
    final fill = (isDark ? cs.surfaceContainerLow : cs.surfaceContainerLowest)
        .withValues(alpha: reduceEffects ? 1 : 0.95);
    final borderColor = isDark
        ? SonoraPulseTokens.darkBorder
        : cs.outlineVariant;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: borderColor),
      ),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: isSwitching
                  ? const ShimmerLoading(variant: ShimmerVariant.miniPlayer)
                  : Row(
                      children: [
                        _MiniArtwork(
                          artUrl: artUrl,
                          size: _artSize,
                          radius: SonoraPulseTokens.radiusSm,
                          cs: cs,
                          isPlaying: isPlaying,
                          useVinylStyle: useVinylStyle,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      currentSong.title,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: cs.onSurface,
                                            height: 1.15,
                                          ),
                                    ),
                                  ),
                                  if (track.isExplicit)
                                    const ExplicitBadge(
                                      leading: SizedBox(width: 6),
                                    ),
                                  if (track.isVideo) ...[
                                    const SizedBox(width: 4),
                                    buildMvBadge(context),
                                  ],
                                ],
                              ),
                              Text(
                                currentSong.artist ?? '',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        MiniPlayerAffinityButton(
                          song: currentSong,
                          iconSize: 22,
                        ),
                        _playButton(
                          blocked: isSwitching,
                          glow: !reduceEffects,
                          isPlaying: isPlaying,
                          isRestoring: playerState.isRestoring,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            playerNotifier.togglePlayPause();
                          },
                        ),
                      ],
                    ),
            ),
            if (!isSwitching)
              Positioned(
                top: 0,
                left: 12,
                right: 12,
                height: kMiniPlayerSeekClearance,
                child: ProgressBarWidget(
                  position: playerState.position,
                  duration: playerState.duration,
                  disabled: playerState.isRestoring,
                  isPlaying: playerState.isPlaying,
                  density: ProgressBarDensity.compact,
                  onSeek: (pos) => playerNotifier.seek(pos),
                ),
              ),
          ],
        ),
      ),
    );

    final clipped = ClipRRect(
      borderRadius: radius,
      child: reduceEffects
          ? card
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: card,
            ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openFullPlayer(context),
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -200) {
          openFullPlayer(context);
        }
      },
      onHorizontalDragEnd: (details) {
        if (isSwitching || details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -250) {
          HapticFeedback.lightImpact();
          playerNotifier.skipToNext();
        } else if (details.primaryVelocity! > 250) {
          HapticFeedback.lightImpact();
          playerNotifier.skipToPrevious();
        }
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: reduceEffects
              ? null
              : [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: isDark ? 0.5 : 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: clipped,
      ),
    );
  }

  Widget _playButton({
    required bool blocked,
    required bool glow,
    required bool isPlaying,
    required bool isRestoring,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: SonoraPulseTokens.playControlDecoration(
        enabled: !blocked,
        glow: glow,
      ),
      child: IconButton(
        icon: AnimatedPlayPauseIcon(
          isPlaying: isPlaying,
          isLoading: isRestoring,
          color: SonoraPulseTokens.onPrimary,
          size: 20,
        ),
        onPressed: blocked ? null : onPressed,
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: SonoraPulseTokens.onPrimary,
          fixedSize: const Size(40, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

class _MiniArtwork extends ConsumerWidget {
  final String? artUrl;
  final double size;
  final double radius;
  final ColorScheme cs;
  final bool isPlaying;
  final bool useVinylStyle;

  const _MiniArtwork({
    required this.artUrl,
    required this.size,
    required this.radius,
    required this.cs,
    required this.isPlaying,
    required this.useVinylStyle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (useVinylStyle) {
      return VinylArtwork(
        imageUrl: artUrl,
        size: size,
        isPlaying: isPlaying,
        useShadow: false,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: artUrl != null
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: CachedNetworkImage(
                  key: ValueKey(artUrl),
                  imageUrl: artUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      Container(color: cs.surfaceContainerHighest),
                  errorWidget: (_, _, _) =>
                      Icon(LucideIcons.music, color: cs.onSurfaceVariant),
                ),
              )
            : Icon(LucideIcons.music, color: cs.onSurfaceVariant),
      ),
    );
  }
}

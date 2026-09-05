import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../domain/models/queue_track.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/vinyl_artwork.dart';
import 'full_player_content.dart';
import 'widgets/animated_play_pause_icon.dart';
import 'widgets/player_shared_widgets.dart';
import 'widgets/progress_bar_widget.dart';

/// Mobile mini player row that sits on top of [MobileShell]'s fused nav dock.
///
/// Chrome (blur, top radius, shared surface) lives on the shell so player and
/// NavigationBar read as one block. Tap or swipe up opens [FullPlayerContent].
/// Swipe left/right skips tracks.
class PlayerSheetMobile extends ConsumerWidget {
  const PlayerSheetMobile({super.key});

  static const double height = 56.0;

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
    final isVideo = QueueTrack.fromMediaItem(currentSong).isVideo;
    final artUrl = currentSong.artUri?.toString();

    final useVinylStyle = ref.watch(
      settingsProvider.select((s) => s.useVinylStyle),
    );

    return GestureDetector(
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
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child:
                  isSwitching
                      ? const ShimmerLoading(variant: ShimmerVariant.miniPlayer)
                      : Row(
                        children: [
                          const SizedBox(width: 12),
                          _MiniArtwork(
                            artUrl: artUrl,
                            size: 40,
                            radius: 8,
                            cs: cs,
                            isPlaying: isPlaying,
                            useVinylStyle: useVinylStyle,
                          ),
                          const SizedBox(width: 10),
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
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                    if (isVideo) ...[
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
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: AnimatedPlayPauseIcon(
                              isPlaying: isPlaying,
                              isLoading: playerState.isRestoring,
                              color: cs.onPrimary,
                              size: 20,
                            ),
                            onPressed:
                                isSwitching
                                    ? null
                                    : () {
                                      HapticFeedback.lightImpact();
                                      playerNotifier.togglePlayPause();
                                    },
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  isSwitching
                                      ? cs.primary.withAlpha(128)
                                      : cs.primary,
                              foregroundColor: cs.onPrimary,
                              fixedSize: const Size(36, 36),
                              shape: const CircleBorder(),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              LucideIcons.skipForward,
                              size: 18,
                              color:
                                  isSwitching
                                      ? cs.onSurfaceVariant.withAlpha(96)
                                      : cs.onSurfaceVariant,
                            ),
                            onPressed:
                                isSwitching
                                    ? null
                                    : () {
                                      HapticFeedback.lightImpact();
                                      playerNotifier.skipToNext();
                                    },
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
            ),
            if (!isSwitching)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ProgressBarWidget(
                  position: playerState.position,
                  duration: playerState.duration,
                  disabled: playerState.isRestoring,
                  isPlaying: playerState.isPlaying,
                  isMini: true,
                ),
              ),
          ],
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
        child:
            artUrl != null
                ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: CachedNetworkImage(
                    key: ValueKey(artUrl),
                    imageUrl: artUrl!,
                    fit: BoxFit.cover,
                    placeholder:
                        (_, _) => Container(color: cs.surfaceContainerHighest),
                    errorWidget:
                        (_, _, _) =>
                            Icon(LucideIcons.music, color: cs.onSurfaceVariant),
                  ),
                )
                : Icon(LucideIcons.music, color: cs.onSurfaceVariant),
      ),
    );
  }
}

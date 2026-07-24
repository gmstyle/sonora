import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../domain/models/queue_track.dart';
import '../../providers/video_player_provider.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/vinyl_artwork.dart';
import 'full_player_content.dart';
import 'widgets/animated_play_pause_icon.dart';
import 'widgets/player_shared_widgets.dart';
import 'widgets/video_player_widget.dart';
import 'widgets/progress_bar_widget.dart';

/// Mobile-only 72 px mini player bar.
///
/// Sits above the navigation bar (placed by [MobileShell] via a [Positioned]
/// with a fixed `height` of 72).  Tapping or swiping up opens [FullPlayerContent]
/// with a slide-up transition identical to the one used by [PlayerSheet] on
/// tablet/wide.  Swiping left/right skips tracks.
class PlayerSheetMobile extends ConsumerWidget {
  const PlayerSheetMobile({super.key});

  void _navigateToFullPlayer(
    BuildContext context,
    WidgetRef ref, {
    PlayerSubView subView = PlayerSubView.none,
  }) {
    if (subView != PlayerSubView.none) {
      ref.read(playerSubViewProvider.notifier).set(subView);
    }
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                FullPlayerContent(initialSubView: subView),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        fullscreenDialog: true,
      ),
    );
  }

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

    final reduceEffects = ref.watch(
      settingsProvider.select((s) => s.reduceEffects),
    );
    final useVinylStyle = ref.watch(
      settingsProvider.select((s) => s.useVinylStyle),
    );

    final innerContent = Stack(
      children: [
        Positioned.fill(
          child: Container(
            color:
                reduceEffects
                    ? cs.surfaceContainerHigh
                    : cs.surfaceContainerHigh.withValues(alpha: 0.82),
            child:
                isSwitching
                    ? const ShimmerLoading(variant: ShimmerVariant.miniPlayer)
                    : Row(
                      children: [
                        const SizedBox(width: 12),
                        _MiniArtwork(
                          artUrl: artUrl,
                          size: 44,
                          radius: 8,
                          cs: cs,
                          isVideo: isVideo,
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
                            size: 22,
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
    );

    // Floating island — same visual language as PlayerSheet on tablet/wide:
    // rounded corners, drop shadow, horizontal margin, BackdropFilter blur.
    return GestureDetector(
      onTap: () => _navigateToFullPlayer(context, ref),
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -200) {
          _navigateToFullPlayer(context, ref);
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
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child:
              reduceEffects
                  ? innerContent
                  : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: innerContent,
                  ),
        ),
      ),
    );
  }
}

// ── Mini artwork ──────────────────────────────────────────────────────────────

class _MiniArtwork extends ConsumerWidget {
  final String? artUrl;
  final double size;
  final double radius;
  final ColorScheme cs;
  final bool isVideo;
  final bool isPlaying;
  final bool useVinylStyle;

  const _MiniArtwork({
    required this.artUrl,
    required this.size,
    required this.radius,
    required this.cs,
    required this.isPlaying,
    required this.useVinylStyle,
    this.isVideo = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoPlayerProvider);
    final enableVideoPlayback = ref.watch(
      settingsProvider.select((s) => s.enableVideoPlayback),
    );
    if (isVideo &&
        shouldShowVideoPlayer(
          enableVideoPlayback: enableVideoPlayback,
          videoState: videoState,
        )) {
      return SonoraVideoPlayer(
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(radius),
        fit: BoxFit.cover,
        showControls: false,
      );
    }
    if (useVinylStyle && !isVideo) {
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

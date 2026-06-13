import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../providers/player_provider.dart';
import '../../providers/video_player_provider.dart';
import '../../shared/widgets/shimmer_loading.dart';
import 'full_player_content.dart';
import 'widgets/animated_play_pause_icon.dart';
import 'widgets/player_shared_widgets.dart';
import 'widgets/video_player_widget.dart';

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
    final isSwitching = playerState.isSwitching;
    final isVideo = currentSong.extras?['isVideo'] == true;
    final artUrl = currentSong.artUri?.toString();

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
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              color: cs.surfaceContainerHigh.withValues(alpha: 0.82),
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
                              color: cs.onPrimary,
                              size: 22,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              playerNotifier.togglePlayPause();
                            },
                            style: IconButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              fixedSize: const Size(36, 36),
                              shape: const CircleBorder(),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              LucideIcons.skipForward,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                            onPressed: () {
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

  const _MiniArtwork({
    required this.artUrl,
    required this.size,
    required this.radius,
    required this.cs,
    this.isVideo = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoState = ref.watch(videoPlayerProvider);
    if (isVideo && videoState.isVideoVisible && videoState.isInitialized) {
      return SonoraVideoPlayer(
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(radius),
        tag: 'video_mini_mobile',
        fit: BoxFit.cover,
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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../providers/player_provider.dart';
import '../screens/tv_now_playing_screen.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import 'tv_focusable.dart';

/// Bottom dock for the TV shell — identity + transport.
///
/// OK on identity opens the TV now-playing overlay. System Back while that
/// overlay is open pops it ([PopScope] in [TvNowPlayingScreen]).
class TvMiniPlayer extends ConsumerWidget {
  const TvMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final song = playerState.currentSong;
    if (song == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final notifier = ref.read(playerStateProvider.notifier);
    final artUrl = song.artUri?.toString();

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: SizedBox(
        height: TvMetrics.miniPlayerHeight,
        child: DpadRegion(
          memoryKey: 'tv/mini-player',
          debugLabel: 'tv/mini-player',
          horizontalEdge: DpadEdgeBehavior.stop,
          verticalEdge: DpadEdgeBehavior.leave,
          onEdge: (direction) {
            if (direction == TraversalDirection.left) {
              TvShellFocus.requestSidebar(context);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                TvFocusable(
                  key: const Key('tv_mini_open_np'),
                  onSelect: () => openTvNowPlaying(context),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child:
                              artUrl != null
                                  ? CachedNetworkImage(
                                    imageUrl: artUrl,
                                    fit: BoxFit.cover,
                                  )
                                  : ColoredBox(
                                    color: theme.colorScheme.surfaceContainer,
                                    child: const Icon(LucideIcons.music),
                                  ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 280,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              song.artist ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                TvFocusable(
                  onSelect: () => notifier.skipToPrevious(),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(LucideIcons.skipBack, size: 28),
                  ),
                ),
                const SizedBox(width: 8),
                TvFocusable(
                  onSelect: () => notifier.togglePlayPause(),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      playerState.isPlaying
                          ? LucideIcons.pause
                          : LucideIcons.play,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TvFocusable(
                  onSelect: () => notifier.skipToNext(),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(LucideIcons.skipForward, size: 28),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

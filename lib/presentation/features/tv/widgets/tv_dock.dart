import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../providers/player_provider.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../screens/tv_now_playing_screen.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import 'tv_focusable.dart';

/// Peep strip under the TV content pane. Opens [TvNowPlayingScreen].
///
/// Reachable via D-pad: Down past the last content focusable, Down from
/// Settings in the rail, or Left from the first dock control back to the rail.
class TvDock extends ConsumerWidget {
  const TvDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerStateProvider);
    final song = player.currentSong;
    if (song == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notifier = ref.read(playerStateProvider.notifier);

    return Material(
      color: colorScheme.surfaceContainerHigh,
      child: SizedBox(
        height: TvMetrics.dockHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TvFocusable(
                  onSelect: () => openTvNowPlaying(context),
                  onLeftAtEdge: () => TvShellFocus.requestSidebar(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      ThumbnailWidget(
                        imageUrl: song.artUri?.toString(),
                        size: 56,
                        shape: ThumbnailShape.rounded,
                        borderRadius: 10,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Flexible(
                              child: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                song.artist ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TvFocusable(
                onSelect: () => notifier.skipToPrevious(),
                borderRadius: BorderRadius.circular(28),
                padding: const EdgeInsets.all(10),
                child: const Icon(LucideIcons.skipBack, size: 26),
              ),
              TvFocusable(
                onSelect: () => notifier.togglePlayPause(),
                borderRadius: BorderRadius.circular(28),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  player.isPlaying ? LucideIcons.pause : LucideIcons.play,
                  size: 30,
                ),
              ),
              TvFocusable(
                onSelect: () => notifier.skipToNext(),
                borderRadius: BorderRadius.circular(28),
                padding: const EdgeInsets.all(10),
                child: const Icon(LucideIcons.skipForward, size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

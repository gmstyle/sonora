import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../providers/player_provider.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../screens/tv_now_playing_screen.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import 'tv_focusable.dart';

/// Thin ATV media-controls strip under the browse pane.
///
/// Opens [TvNowPlayingScreen]. Kept short so browser rows stay primary —
/// this is not a phone mini-player card.
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TvFocusable(
                  onSelect: () => openTvNowPlaying(context),
                  onLeftAtEdge: () => TvShellFocus.requestSidebar(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      ThumbnailWidget(
                        imageUrl: song.artUri?.toString(),
                        size: TvMetrics.dockArtSize,
                        shape: ThumbnailShape.rounded,
                        borderRadius: 4,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${song.title} · ${song.artist ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TvFocusable(
                onSelect: () => notifier.skipToPrevious(),
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  LucideIcons.skipBack,
                  size: TvMetrics.dockIconSize,
                ),
              ),
              TvFocusable(
                onSelect: () => notifier.togglePlayPause(),
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(4),
                child: Icon(
                  player.isPlaying ? LucideIcons.pause : LucideIcons.play,
                  size: TvMetrics.dockIconSize + 2,
                ),
              ),
              TvFocusable(
                onSelect: () => notifier.skipToNext(),
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  LucideIcons.skipForward,
                  size: TvMetrics.dockIconSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

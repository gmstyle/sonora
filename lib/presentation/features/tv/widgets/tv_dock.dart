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
    final progress = player.duration.inMilliseconds > 0
        ? (player.position.inMilliseconds / player.duration.inMilliseconds)
              .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: TvColors.dockBg,
        border: Border(top: BorderSide(color: TvColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
          SizedBox(
            height: TvMetrics.dockHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TvFocusable(
                      onSelect: () => openTvNowPlaying(context),
                      onLeftAtEdge: () => TvShellFocus.requestSidebar(context),
                      borderRadius: BorderRadius.circular(10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          ThumbnailWidget(
                            imageUrl: song.artUri?.toString(),
                            size: TvMetrics.dockArtSize,
                            shape: ThumbnailShape.rounded,
                            borderRadius: 8,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: song.title,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: TvColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (song.artist != null &&
                                      song.artist!.isNotEmpty) ...[
                                    TextSpan(
                                      text: '  •  ',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: TvColors.textSecondary,
                                          ),
                                    ),
                                    TextSpan(
                                      text: song.artist!,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: TvColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (player.isPlaying) ...[
                            const SizedBox(width: 10),
                            _MiniEqBars(color: colorScheme.primary),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TvFocusable(
                    onSelect: () => notifier.skipToPrevious(),
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      LucideIcons.skipBack,
                      size: TvMetrics.dockIconSize,
                      color: TvColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TvFocusable(
                    onSelect: () => notifier.togglePlayPause(),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary,
                      ),
                      child: Icon(
                        player.isPlaying ? LucideIcons.pause : LucideIcons.play,
                        size: 16,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TvFocusable(
                    onSelect: () => notifier.skipToNext(),
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      LucideIcons.skipForward,
                      size: TvMetrics.dockIconSize,
                      color: TvColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniEqBars extends StatelessWidget {
  final Color color;

  const _MiniEqBars({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 2.5,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          width: 2.5,
          height: 13,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          width: 2.5,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

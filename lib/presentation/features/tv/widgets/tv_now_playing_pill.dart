import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../providers/player_provider.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../screens/tv_now_playing_screen.dart';
import '../tv_metrics.dart';
import 'tv_focusable.dart';

/// Compact top-right "Now Playing" pill for Android TV browse screens.
///
/// Replaces the mobile-style bottom bar so 16:9 vertical space stays dedicated
/// to shelves and the Hero Spotlight. Pressing Select opens
/// [TvNowPlayingScreen].
class TvNowPlayingPill extends ConsumerWidget {
  final FocusNode? focusNode;

  const TvNowPlayingPill({super.key, this.focusNode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerStateProvider);
    final song = player.currentSong;
    if (song == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = player.duration.inMilliseconds > 0
        ? (player.position.inMilliseconds / player.duration.inMilliseconds)
              .clamp(0.0, 1.0)
        : 0.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 268),
      child: TvFocusable(
        focusNode: focusNode,
        onSelect: () => openTvNowPlaying(context),
        borderRadius: BorderRadius.circular(99),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xE60B0E17),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: TvColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 5, 14, 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ThumbnailWidget(
                        imageUrl: song.artUri?.toString(),
                        size: 30,
                        shape: ThumbnailShape.circle,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: TvColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                            if (song.artist != null &&
                                song.artist!.isNotEmpty)
                              Text(
                                song.artist!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: TvColors.textSecondary,
                                  fontSize: 10,
                                  height: 1.15,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (player.isPlaying)
                        TvMiniEqBars(color: colorScheme.primary)
                      else
                        Icon(
                          LucideIcons.pause,
                          size: 13,
                          color: colorScheme.primary,
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 0,
                  child: SizedBox(
                    height: 2,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        colorScheme.primary,
                      ),
                    ),
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

/// Compact 3-bar audio indicator used in [TvNowPlayingPill] and sidebar.
class TvMiniEqBars extends StatelessWidget {
  final Color color;

  const TvMiniEqBars({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 2.5,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          width: 2.5,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          width: 2.5,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

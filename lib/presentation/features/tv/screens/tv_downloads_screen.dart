import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_poster_card.dart';
import '../widgets/tv_poster_grid.dart';

/// TV downloads: completed poster grid + active queue summary.
///
/// Wraps the entire screen in a [Focus] catch-all so that ArrowLeft always
/// escapes to the sidebar — even from an [EmptyStateWidget] or the loading
/// shimmer, which are not individually focusable.
class TvDownloadsScreen extends ConsumerWidget {
  const TvDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final active = ref.watch(activeDownloadsProvider);
    final allAsync = ref.watch(allDownloadsProvider);
    final theme = Theme.of(context);

    // Catch-all ArrowLeft handler: if no child consumed the key (e.g. empty
    // state, shimmer, or first column of the grid handled via onLeftAtEdge),
    // fall through here and hand off to the sidebar.
    return Focus(
      // Not autofocus — let the grid items or TvPosterCard absorb focus first.
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          TvShellFocus.requestSidebar(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TvMetrics.contentPadding,
              TvMetrics.browseTopPadding,
              TvMetrics.contentPadding,
              12,
            ),
            child: Text(
              l10n.downloads,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: TvColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (active.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TvMetrics.contentPadding,
                vertical: 6,
              ),
              child: Text(
                l10n.downloadsInProgress(active.length),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          Expanded(
            child: allAsync.when(
              loading: () => const SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: ShimmerLoading(
                  variant: ShimmerVariant.mediaGrid,
                  gridColumns: 4,
                ),
              ),
              error: (e, _) => ErrorRetryWidget(
                message: l10n.failedToLoadDownloads,
                onRetry: () => ref.invalidate(allDownloadsProvider),
              ),
              data: (downloads) {
                final completed = downloads
                    .where(
                      (d) => d.status == 'completed' || d.localPath != null,
                    )
                    .toList();
                if (completed.isEmpty) {
                  // Wrap EmptyStateWidget in a TvFocusable so ArrowLeft can
                  // bubble up to the catch-all Focus above and reach the rail.
                  return TvFocusable(
                    onLeftAtEdge: () => TvShellFocus.requestSidebar(context),
                    child: EmptyStateWidget(
                      icon: LucideIcons.download,
                      title: l10n.noDownloadsYet,
                    ),
                  );
                }
                return TvPosterGrid(
                  itemCount: completed.length,
                  itemBuilder: (context, index) {
                    final item = completed[index];
                    return TvPosterCard(
                      title: item.title,
                      subtitle: item.artist,
                      imageUrl: item.thumbnailUrl,
                      onLeftAtEdge: index == 0
                          ? () => TvShellFocus.requestSidebar(context)
                          : null,
                      onSelect: () => ref
                          .read(playerStateProvider.notifier)
                          .playVideoId(
                            item.videoId,
                            isVideo: item.isVideo,
                            isExplicit: item.isExplicit,
                          ),
                      onLongSelect: () => ContextMenuSheet.showForSong(
                        context,
                        videoId: item.videoId,
                        title: item.title,
                        artist: item.artist,
                        artistsJson: item.artistsJson,
                        thumbnailUrl: item.thumbnailUrl,
                        isVideo: item.isVideo,
                        isExplicit: item.isExplicit,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

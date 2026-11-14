import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_poster_card.dart';

/// TV downloads: completed poster grid + active queue summary.
class TvDownloadsScreen extends ConsumerWidget {
  const TvDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final active = ref.watch(activeDownloadsProvider);
    final allAsync = ref.watch(allDownloadsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TvMetrics.contentPadding,
            28,
            TvMetrics.contentPadding,
            8,
          ),
          child: Text(
            l10n.downloads,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (active.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TvMetrics.contentPadding,
              vertical: 8,
            ),
            child: Text('${active.length}', style: theme.textTheme.titleMedium),
          ),
        Expanded(
          child: allAsync.when(
            loading: () =>
                const ShimmerLoading(variant: ShimmerVariant.mediaGrid),
            error: (e, _) => ErrorRetryWidget(
              message: l10n.failedToLoadDownloads,
              onRetry: () => ref.invalidate(allDownloadsProvider),
            ),
            data: (downloads) {
              final completed = downloads
                  .where((d) => d.status == 'completed' || d.localPath != null)
                  .toList();
              if (completed.isEmpty) {
                return EmptyStateWidget(
                  icon: LucideIcons.download,
                  title: l10n.noDownloadsYet,
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.all(TvMetrics.contentPadding),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: TvMetrics.shelfCardWidth + 24,
                  mainAxisExtent: TvMetrics.shelfRowHeight,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
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
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

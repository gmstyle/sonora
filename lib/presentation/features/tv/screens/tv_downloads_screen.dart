import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/download_group.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../downloads/widgets/completed_downloads_view.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/tv_poster_card.dart';

/// Android TV downloads: active queue + completed groups with D-pad focus.
class TvDownloadsScreen extends ConsumerWidget {
  const TvDownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final activeDownloads = ref.watch(activeDownloadsProvider);
    final allDownloadsAsync = ref.watch(allDownloadsProvider);
    final groups = ref.watch(downloadGroupsProvider);
    final sort = ref.watch(downloadsSortProvider);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TvMetrics.horizontalPadding,
              TvMetrics.verticalPadding,
              TvMetrics.horizontalPadding,
              8,
            ),
            child: Text(
              l10n.downloads,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: allDownloadsAsync.when(
              loading:
                  () => const Center(
                    child: ShimmerLoading(variant: ShimmerVariant.section),
                  ),
              error:
                  (_, _) => ErrorRetryWidget(
                    message: l10n.failedToLoadDownloads,
                    onRetry: () => ref.invalidate(allDownloadsProvider),
                  ),
              data: (completed) {
                final activeItems = [
                  for (final d in activeDownloads.values)
                    if (d.status == DownloadStatus.downloading) d,
                  for (final d in activeDownloads.values)
                    if (d.status == DownloadStatus.pending) d,
                  for (final d in activeDownloads.values)
                    if (d.status == DownloadStatus.completed ||
                        d.status == DownloadStatus.error)
                      d,
                ];
                final hasActive = activeItems.isNotEmpty;
                final hasCompleted = completed.isNotEmpty;

                if (!hasActive && !hasCompleted) {
                  return EmptyStateWidget(
                    icon: LucideIcons.download,
                    title: l10n.noDownloadsYet,
                    body: l10n.noDownloadsHint,
                    buttonLabel: l10n.goToSearch,
                    onButtonPressed: () => context.go('/search'),
                  );
                }

                return DpadRegion(
                  memoryKey: 'tv/downloads/list',
                  debugLabel: 'tv/downloads/list',
                  horizontalEdge: DpadEdgeBehavior.stop,
                  onEdge: (direction) {
                    if (direction == TraversalDirection.left) {
                      TvShellFocus.requestSidebar(context);
                    }
                  },
                  child: CustomScrollView(
                    slivers: [
                      if (hasActive) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              TvMetrics.horizontalPadding,
                              8,
                              TvMetrics.horizontalPadding,
                              8,
                            ),
                            child: Text(
                              l10n.activeDownloads,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TvMetrics.horizontalPadding,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final download = activeItems[index];
                              return _TvActiveDownloadTile(
                                download: download,
                                autofocus: index == 0,
                              );
                            }, childCount: activeItems.length),
                          ),
                        ),
                      ],
                      if (hasCompleted) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              TvMetrics.horizontalPadding,
                              hasActive ? 24 : 8,
                              TvMetrics.horizontalPadding,
                              8,
                            ),
                            child: Text(
                              l10n.downloaded,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            TvMetrics.horizontalPadding,
                            0,
                            TvMetrics.horizontalPadding,
                            TvMetrics.verticalPadding,
                          ),
                          sliver: SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: TvMetrics.cardWidth + 24,
                                  mainAxisExtent: TvMetrics.cardExtent,
                                  crossAxisSpacing: TvMetrics.cardGap,
                                  mainAxisSpacing: TvMetrics.cardGap,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final group = groups[index];
                              return _TvDownloadGroupCard(
                                group: group,
                                sort: sort,
                                autofocus: !hasActive && index == 0,
                              );
                            }, childCount: groups.length),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TvActiveDownloadTile extends ConsumerWidget {
  final ActiveDownload download;
  final bool autofocus;

  const _TvActiveDownloadTile({required this.download, this.autofocus = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final canCancel =
        download.status == DownloadStatus.downloading ||
        download.status == DownloadStatus.pending;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TvFocusable(
        autofocus: autofocus,
        onSelect:
            canCancel
                ? () => ref
                    .read(activeDownloadsProvider.notifier)
                    .cancelDownload(download.videoId)
                : null,
        child: Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                download.status == DownloadStatus.error
                    ? LucideIcons.alertCircle
                    : LucideIcons.download,
                color:
                    download.status == DownloadStatus.error
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      download.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusLabel(l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (download.status == DownloadStatus.downloading) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: download.progress),
                    ],
                  ],
                ),
              ),
              if (canCancel)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    l10n.cancel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n) {
    return switch (download.status) {
      DownloadStatus.downloading =>
        '${(download.progress * 100).round()}% · ${download.artist}',
      DownloadStatus.pending => '${l10n.downloadQueued} · ${download.artist}',
      DownloadStatus.error => switch (download.error) {
        DownloadError.wifiRestricted => l10n.downloadErrorWifi,
        DownloadError.network => l10n.downloadErrorNetwork,
        DownloadError.storage => l10n.downloadErrorStorage,
        DownloadError.unknown || null => l10n.downloadFailed,
      },
      DownloadStatus.completed => l10n.downloadComplete,
    };
  }
}

class _TvDownloadGroupCard extends ConsumerWidget {
  final DownloadGroup group;
  final DownloadsSort sort;
  final bool autofocus;

  const _TvDownloadGroupCard({
    required this.group,
    required this.sort,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final subtitle = switch (group.kind) {
      DownloadGroupKind.singles =>
        '${group.tracks.length} · ${downloadGroupSectionTitle(l10n, group.kind)}',
      _ =>
        '${group.tracks.length} · ${downloadGroupSectionTitle(l10n, group.kind)}',
    };

    return TvPosterCard(
      title: group.name,
      subtitle: subtitle,
      thumbnailUrl: group.thumbnailUrl,
      autofocus: autofocus,
      onSelect: () async {
        if (group.kind == DownloadGroupKind.singles &&
            group.tracks.length == 1) {
          final track = group.tracks.first;
          ref
              .read(playerStateProvider.notifier)
              .playVideoId(
                track.videoId,
                isVideo: track.isVideo,
                isExplicit: track.isExplicit,
              );
          return;
        }
        await playDownloadGroup(ref, group, sort);
      },
      onLongSelect: () => _showGroupMenu(context, ref),
    );
  }

  Future<void> _showGroupMenu(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    if (group.tracks.length == 1) {
      final track = group.tracks.first;
      await ContextMenuSheet.showForSong(
        context,
        videoId: track.videoId,
        title: track.title,
        artist: track.artist,
        artistsJson: track.artistsJson,
        thumbnailUrl: track.thumbnailUrl,
        isVideo: track.isVideo,
        isExplicit: track.isExplicit,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(l10n.deleteDownloadCollection),
            content: Text(
              l10n.deleteDownloadCollectionConfirm(
                group.tracks.length,
                group.name,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.delete),
              ),
            ],
          ),
    );
    if (confirm == true) {
      final notifier = ref.read(activeDownloadsProvider.notifier);
      for (final track in List<DownloadModel>.from(group.tracks)) {
        await notifier.deleteDownload(track.videoId);
      }
    }
  }
}

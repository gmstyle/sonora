import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/duration_ext.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/download_provider.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/thumbnail_widget.dart';
import 'widgets/completed_downloads_view.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDownloads = ref.watch(activeDownloadsProvider);
    final allDownloadsAsync = ref.watch(allDownloadsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isWide = screenWidth >= kExpandedBreakpoint;
        final isTablet = screenWidth >= kCompactBreakpoint;
        final isCompact = screenWidth < kCompactBreakpoint;

        Widget contentWidget() {
          return allDownloadsAsync.when(
            loading:
                () => ListView.builder(
                  itemCount: 6,
                  padding: const EdgeInsets.only(top: 8),
                  itemBuilder:
                      (_, _) =>
                          const ShimmerLoading(variant: ShimmerVariant.tile),
                ),
            error:
                (e, _) => ErrorRetryWidget(
                  message: AppLocalizations.of(context)!.failedToLoadDownloads,
                  onRetry: () => ref.invalidate(allDownloadsProvider),
                ),
            data: (completed) {
              final hasActive = activeDownloads.isNotEmpty;
              final hasCompleted = completed.isNotEmpty;

              if (!hasActive && !hasCompleted) {
                final l10n = AppLocalizations.of(context)!;
                return EmptyStateWidget(
                  icon: LucideIcons.download,
                  title: l10n.noDownloadsYet,
                  body: l10n.noDownloadsHint,
                  buttonLabel: l10n.goToSearch,
                  onButtonPressed: () => context.go('/search'),
                );
              }

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

              if (isCompact) {
                return CustomScrollView(
                  slivers: [
                    if (hasActive)
                      _ActiveDownloadsSection(
                        activeDownloads: activeItems,
                        isTablet: isTablet,
                        ref: ref,
                      ),
                    if (hasCompleted) const CompletedDownloadsSliver(),
                  ],
                );
              }

              // Tablet / wide: actives full-width above master–detail split.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasActive)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: CustomScrollView(
                        shrinkWrap: true,
                        slivers: [
                          _ActiveDownloadsSection(
                            activeDownloads: activeItems,
                            isTablet: isTablet,
                            ref: ref,
                          ),
                        ],
                      ),
                    ),
                  if (hasCompleted)
                    Expanded(child: CompletedDownloadsView(isCompact: false)),
                ],
              );
            },
          );
        }

        if (isCompact) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.downloads),
            ),
            body: contentWidget(),
          );
        }

        final theme = Theme.of(context);
        // Shared title + list for tablet/wide; Card only at >= 1200.
        final splitContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                AppLocalizations.of(context)!.downloads,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(child: contentWidget()),
          ],
        );

        // Card + document padding only at >= kExpandedBreakpoint (1200).
        // Tablet 600–1199: full-bleed content on shell surface.
        final Widget body =
            isWide
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48.0,
                      vertical: 32.0,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        color: theme.colorScheme.surfaceContainerLow,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: splitContent,
                        ),
                      ),
                    ),
                  ),
                )
                : splitContent;

        return Scaffold(backgroundColor: theme.colorScheme.surface, body: body);
      },
    );
  }
}

String _formatBytes(int? bytes) {
  return formatDownloadBytes(bytes);
}

class _ActiveDownloadsSection extends StatelessWidget {
  final List<ActiveDownload> activeDownloads;
  final bool isTablet;
  final WidgetRef ref;

  const _ActiveDownloadsSection({
    required this.activeDownloads,
    required this.isTablet,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final batches = ref.watch(downloadBatchesProvider);
    final groups = _groupActive(activeDownloads, batches);
    final showCancelAll = groups.length > 1;

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 8, isTablet ? 4 : 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.activeDownloads,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (showCancelAll)
                  TextButton(
                    onPressed:
                        () =>
                            ref
                                .read(activeDownloadsProvider.notifier)
                                .cancelAll(),
                    child: Text(l10n.cancelAllDownloads),
                  ),
              ],
            ),
          ),
        ),
        for (final group in groups) ...[
          if (group.batchId != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.title,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          () => ref
                              .read(activeDownloadsProvider.notifier)
                              .cancelBatch(group.batchId!),
                      child: Text(l10n.cancelBatchDownload),
                    ),
                  ],
                ),
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final d = group.items[index];
              return _ActiveDownloadTile(download: d, ref: ref);
            }, childCount: group.items.length),
          ),
        ],
      ],
    );
  }

  List<_ActiveGroup> _groupActive(
    List<ActiveDownload> items,
    Map<String, DownloadBatchProgress> batches,
  ) {
    final ordered = <_ActiveGroup>[];
    final indexByKey = <String, int>{};

    for (final item in items) {
      final key = item.batchId ?? 'single:${item.videoId}';
      final existingIndex = indexByKey[key];
      if (existingIndex != null) {
        ordered[existingIndex].items.add(item);
        continue;
      }

      final String title;
      if (item.batchId != null) {
        final batch = batches[item.batchId!];
        final name = batch?.name ?? item.batchName ?? '';
        final done = batch?.completed ?? 0;
        final total = batch?.total ?? item.batchTotal ?? 0;
        title = '$name · $done/$total';
      } else {
        title = item.title;
      }

      indexByKey[key] = ordered.length;
      ordered.add(
        _ActiveGroup(
          key: key,
          batchId: item.batchId,
          title: title,
          items: [item],
        ),
      );
    }

    for (final group in ordered) {
      if (group.batchId == null) continue;
      if (group.items.every((d) => d.collectionIndex == null)) continue;
      group.items.sort((a, b) {
        final aIndex = a.collectionIndex;
        final bIndex = b.collectionIndex;
        if (aIndex != null && bIndex != null) {
          return aIndex.compareTo(bIndex);
        }
        if (aIndex != null) return -1;
        if (bIndex != null) return 1;
        return 0;
      });
    }
    return ordered;
  }
}

class _ActiveGroup {
  final String key;
  final String? batchId;
  final String title;
  final List<ActiveDownload> items;

  _ActiveGroup({
    required this.key,
    required this.batchId,
    required this.title,
    required this.items,
  });
}

class _ActiveDownloadTile extends StatelessWidget {
  final ActiveDownload download;
  final WidgetRef ref;

  const _ActiveDownloadTile({required this.download, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildThumbnail(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      download.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      download.artist,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _buildStatusBlock(context, l10n, theme),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildTrailing(context, l10n, theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        ThumbnailWidget(
          imageUrl: download.thumbnailUrl,
          size: 48,
          shape: ThumbnailShape.rounded,
        ),
        if (download.status == DownloadStatus.pending)
          _ThumbnailOverlay(
            icon: LucideIcons.clock,
            iconColor: theme.colorScheme.onInverseSurface,
          )
        else if (download.status == DownloadStatus.error)
          _ThumbnailOverlay(
            icon: LucideIcons.alertCircle,
            iconColor: theme.colorScheme.onError,
            scrim: theme.colorScheme.error.withValues(alpha: 0.75),
          )
        else if (download.status == DownloadStatus.completed)
          _ThumbnailOverlay(
            icon: LucideIcons.check,
            iconColor: theme.colorScheme.onPrimary,
            scrim: theme.colorScheme.primary.withValues(alpha: 0.75),
          ),
      ],
    );
  }

  Widget _buildStatusBlock(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    switch (download.status) {
      case DownloadStatus.downloading:
        final remaining = download.remaining;
        final speed = download.speedBytesPerSec;
        final metaParts = [
          if (speed != null && speed > 0) '${_formatBytes(speed.round())}/s',
          if (remaining != null) l10n.downloadTimeLeft(remaining.format()),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: download.progress),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder:
                        (context, value, _) =>
                            LinearProgressIndicator(value: value),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(download.progress * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            if (metaParts.isNotEmpty || download.totalBytes > 0) ...[
              const SizedBox(height: 4),
              Text(
                [
                  ...metaParts,
                  if (download.totalBytes > 0)
                    '${_formatBytes(download.receivedBytes)}/${_formatBytes(download.totalBytes)}',
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
      case DownloadStatus.pending:
        return Text(
          l10n.downloadQueued,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      case DownloadStatus.completed:
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 300),
          builder: (context, value, _) => LinearProgressIndicator(value: value),
        );
      case DownloadStatus.error:
        return Text(
          _errorMessage(context, download.error),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
    }
  }

  Widget _buildTrailing(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    switch (download.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.pending:
        return IconButton(
          key: const ValueKey('cancel'),
          tooltip: l10n.cancelDownload,
          icon: Icon(LucideIcons.x, color: theme.colorScheme.onSurfaceVariant),
          onPressed:
              () => ref
                  .read(activeDownloadsProvider.notifier)
                  .cancelDownload(download.videoId),
          visualDensity: VisualDensity.compact,
        );
      case DownloadStatus.completed:
        return Icon(
          LucideIcons.checkCircle,
          key: const ValueKey('completed'),
          color: theme.colorScheme.primary,
          size: 24,
        );
      case DownloadStatus.error:
        return IconButton(
          key: const ValueKey('retry'),
          icon: Icon(LucideIcons.refreshCw, color: theme.colorScheme.error),
          onPressed:
              () => ref
                  .read(activeDownloadsProvider.notifier)
                  .retry(download.videoId),
          visualDensity: VisualDensity.compact,
        );
    }
  }

  String _errorMessage(BuildContext context, DownloadError? error) {
    final l10n = AppLocalizations.of(context)!;
    return switch (error) {
      DownloadError.wifiRestricted => l10n.downloadErrorWifi,
      DownloadError.network => l10n.downloadErrorNetwork,
      DownloadError.storage => l10n.downloadErrorStorage,
      DownloadError.unknown || null => l10n.downloadFailed,
    };
  }
}

class _ThumbnailOverlay extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color? scrim;

  const _ThumbnailOverlay({
    required this.icon,
    required this.iconColor,
    this.scrim,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: scrim ?? Colors.black.withValues(alpha: 0.55),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }
}

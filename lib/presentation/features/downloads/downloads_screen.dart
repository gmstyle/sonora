import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/duration_ext.dart';
import '../../../domain/models/library_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/download_provider.dart';
import '../../providers/player_provider.dart';
import '../../shared/widgets/context_menu_sheet.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/explicit_badge.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/thumbnail_widget.dart';

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
              final sort = ref.watch(downloadsSortProvider);
              final sortedCompleted = _sortCompleted(completed, sort);

              return CustomScrollView(
                slivers: [
                  if (hasActive)
                    _ActiveDownloadsSection(
                      activeDownloads: activeItems,
                      isTablet: isTablet,
                      ref: ref,
                    ),
                  if (hasCompleted)
                    _CompletedDownloadsSection(
                      completed: sortedCompleted,
                      sort: sort,
                      ref: ref,
                    ),
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
        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 48.0 : 16.0,
                vertical: isWide ? 32.0 : 16.0,
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
                    child: Column(
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
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<DownloadModel> _sortCompleted(
    List<DownloadModel> items,
    DownloadsSort sort,
  ) {
    final sorted = List<DownloadModel>.of(items);
    switch (sort) {
      case DownloadsSort.newest:
        sorted.sort(
          (a, b) => (b.downloadedAt ?? DateTime(0)).compareTo(
            a.downloadedAt ?? DateTime(0),
          ),
        );
      case DownloadsSort.title:
        sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case DownloadsSort.largest:
        sorted.sort((a, b) => (b.fileSize ?? 0).compareTo(a.fileSize ?? 0));
    }
    return sorted;
  }
}

String _formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
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
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, isTablet ? 4 : 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              AppLocalizations.of(context)!.activeDownloads,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final d = activeDownloads[index];
            return _ActiveDownloadTile(download: d, ref: ref);
          }, childCount: activeDownloads.length),
        ),
      ],
    );
  }
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

class _CompletedDownloadsSection extends StatelessWidget {
  final List<DownloadModel> completed;
  final DownloadsSort sort;
  final WidgetRef ref;

  const _CompletedDownloadsSection({
    required this.completed,
    required this.sort,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final totalBytes = completed.fold<int>(
      0,
      (sum, d) => sum + (d.fileSize ?? 0),
    );

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.downloadedSongs,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          l10n.downloadsStats(completed.length),
                          if (totalBytes > 0) _formatBytes(totalBytes),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _SortMenu(currentSort: sort, ref: ref),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final d = completed[index];
              return _CompletedDownloadTile(download: d, ref: ref);
            }, childCount: completed.length),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
        ),
      ],
    );
  }
}

class _SortMenu extends StatelessWidget {
  final DownloadsSort currentSort;
  final WidgetRef ref;

  const _SortMenu({required this.currentSort, required this.ref});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = {
      DownloadsSort.newest: l10n.sortNewest,
      DownloadsSort.title: l10n.sortByTitle,
      DownloadsSort.largest: l10n.sortBySize,
    };

    return PopupMenuButton<DownloadsSort>(
      tooltip: l10n.sortDownloads,
      icon: const Icon(LucideIcons.arrowUpDown, size: 18),
      onSelected:
          (value) => ref.read(downloadsSortProvider.notifier).update(value),
      itemBuilder:
          (context) => [
            for (final entry in options.entries)
              PopupMenuItem<DownloadsSort>(
                value: entry.key,
                child: Row(
                  children: [
                    Icon(
                      currentSort == entry.key ? LucideIcons.check : null,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(entry.value),
                  ],
                ),
              ),
          ],
    );
  }
}

class _CompletedDownloadTile extends StatelessWidget {
  final DownloadModel download;
  final WidgetRef ref;

  const _CompletedDownloadTile({required this.download, required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final subtitleParts = [
      download.artist,
      if (download.fileSize != null) _formatBytes(download.fileSize),
      if (download.downloadedAt != null)
        MaterialLocalizations.of(
          context,
        ).formatMediumDate(download.downloadedAt!),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Card(
        child: ListTile(
          leading: ThumbnailWidget(
            imageUrl: download.thumbnailUrl,
            size: 48,
            shape: ThumbnailShape.rounded,
          ),
          title: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              children: [
                if (download.isExplicit)
                  const WidgetSpan(
                    child: Padding(
                      padding: EdgeInsets.only(right: 6.0),
                      child: ExplicitBadge(),
                    ),
                    alignment: PlaceholderAlignment.middle,
                  ),
                TextSpan(text: download.title),
              ],
            ),
          ),
          subtitle: Text(
            subtitleParts.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: Icon(
              LucideIcons.trash2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: Text(l10n.deleteDownload),
                      content: Text(l10n.deleteDownloadConfirm(download.title)),
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
                await ref
                    .read(activeDownloadsProvider.notifier)
                    .deleteDownload(download.videoId);
              }
            },
          ),
          onTap: () {
            ref
                .read(playerStateProvider.notifier)
                .playVideoId(
                  download.videoId,
                  isVideo: download.isVideo,
                  isExplicit: download.isExplicit,
                );
          },
          onLongPress:
              () => ContextMenuSheet.showForSong(
                context,
                videoId: download.videoId,
                title: download.title,
                artist: download.artist,
                thumbnailUrl: download.thumbnailUrl,
                isVideo: download.isVideo,
                isExplicit: download.isExplicit,
              ),
        ),
      ),
    );
  }
}

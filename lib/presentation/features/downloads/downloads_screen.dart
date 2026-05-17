import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../providers/download_provider.dart';
import '../../providers/player_provider.dart';
import '../../shared/widgets/thumbnail_widget.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDownloads = ref.watch(activeDownloadsProvider);
    final allDownloadsAsync = ref.watch(allDownloadsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kExpandedBreakpoint;
        final isTablet = constraints.maxWidth >= kCompactBreakpoint;

        return Scaffold(
          appBar: AppBar(title: const Text('Downloads')),
          body: allDownloadsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (completed) {
              final hasActive = activeDownloads.isNotEmpty;
              final hasCompleted = completed.isNotEmpty;

              if (!hasActive && !hasCompleted) {
                return _EmptyState(isTablet: isTablet);
              }

              final crossAxisCount = isWide ? 3 : (isTablet ? 2 : 1);

              return CustomScrollView(
                slivers: [
                  if (hasActive) _ActiveDownloadsSection(
                    activeDownloads: activeDownloads,
                    isTablet: isTablet,
                    ref: ref,
                  ),
                  if (hasCompleted) _CompletedDownloadsSection(
                    completed: completed,
                    crossAxisCount: crossAxisCount,
                    ref: ref,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isTablet;
  const _EmptyState({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 64 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No downloads yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Long-press on any song and select Download\nto save it for offline playback.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveDownloadsSection extends StatelessWidget {
  final Map<String, ActiveDownload> activeDownloads;
  final bool isTablet;
  final WidgetRef ref;

  const _ActiveDownloadsSection({
    required this.activeDownloads,
    required this.isTablet,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final items = activeDownloads.values.toList();
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, isTablet ? 4 : 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Active Downloads',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final d = items[index];
              return _ActiveDownloadTile(download: d, ref: ref);
            },
            childCount: items.length,
          ),
        ),
      ],
    );
  }
}

class _ActiveDownloadTile extends StatelessWidget {
  final ActiveDownload download;
  final WidgetRef ref;

  const _ActiveDownloadTile({
    required this.download,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 48,
                  height: 48,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.music_note, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      download.title,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
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
                    if (download.status == DownloadStatus.downloading)
                      LinearProgressIndicator(value: download.progress)
                    else if (download.status == DownloadStatus.error)
                      Text(
                        download.errorMessage ?? 'Download failed',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.error),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (download.status == DownloadStatus.downloading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: download.progress > 0 ? download.progress : null,
                    strokeWidth: 2.5,
                  ),
                )
              else if (download.status == DownloadStatus.completed)
                Icon(Icons.check_circle,
                    color: theme.colorScheme.primary, size: 24)
              else if (download.status == DownloadStatus.error)
                IconButton(
                  icon: Icon(Icons.refresh, color: theme.colorScheme.error),
                  onPressed: () => ref
                      .read(activeDownloadsProvider.notifier)
                      .retry(
                        videoId: download.videoId,
                        title: download.title,
                        artist: download.artist,
                        thumbnailUrl: download.thumbnailUrl,
                      ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedDownloadsSection extends StatelessWidget {
  final List completed;
  final int crossAxisCount;
  final WidgetRef ref;

  const _CompletedDownloadsSection({
    required this.completed,
    required this.crossAxisCount,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Downloaded Songs',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final d = completed[index];
                return _CompletedDownloadTile(download: d, ref: ref);
              },
              childCount: completed.length,
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }
}

class _CompletedDownloadTile extends StatelessWidget {
  final dynamic download;
  final WidgetRef ref;

  const _CompletedDownloadTile({
    required this.download,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Card(
        child: ListTile(
          leading: ThumbnailWidget(
            imageUrl: download.thumbnailUrl as String?,
            size: 48,
            shape: ThumbnailShape.rounded,
          ),
          title: Text(
            download.title,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${download.artist} · ${_formatSize(download.fileSize)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline,
                color: theme.colorScheme.onSurfaceVariant),
            onPressed: () =>
                ref.read(activeDownloadsProvider.notifier).deleteDownload(
                      download.videoId as String,
                    ),
          ),
          onTap: () {
            ref.read(playerStateProvider.notifier).playVideoId(
                  download.videoId as String,
                );
          },
        ),
      ),
    );
  }

  String _formatSize(dynamic bytes) {
    if (bytes == null) return 'unknown size';
    final b = bytes as int;
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../domain/models/download_group.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/play_video_id_use_case_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/explicit_badge.dart';
import '../../../shared/widgets/thumbnail_widget.dart';

/// Persists master–detail selection across rebuilds (tablet/wide).
class SelectedDownloadGroupKeyNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? key) => state = key;
}

final selectedDownloadGroupKeyProvider =
    NotifierProvider<SelectedDownloadGroupKeyNotifier, String?>(
      SelectedDownloadGroupKeyNotifier.new,
    );

String downloadGroupSectionTitle(
  AppLocalizations l10n,
  DownloadGroupKind kind,
) {
  return switch (kind) {
    DownloadGroupKind.album => l10n.albums,
    DownloadGroupKind.playlist => l10n.playlists,
    DownloadGroupKind.podcast => l10n.podcasts,
    DownloadGroupKind.localPlaylist => l10n.myPlaylists,
    DownloadGroupKind.inferred => l10n.downloadGroupFolders,
    DownloadGroupKind.singles => l10n.downloadSingles,
  };
}

List<DownloadModel> sortDownloadTracks(
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

String formatDownloadBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final digits = unit == 0 ? 0 : 1;
  return '${size.toStringAsFixed(digits)} ${units[unit]}';
}

class CompletedDownloadsView extends ConsumerWidget {
  final bool isCompact;

  const CompletedDownloadsView({super.key, required this.isCompact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(downloadGroupsProvider);
    final sort = ref.watch(downloadsSortProvider);

    if (groups.isEmpty) return const SizedBox.shrink();

    if (isCompact) {
      return _MobileCompletedDownloads(groups: groups, sort: sort);
    }
    return _SplitCompletedDownloads(groups: groups, sort: sort);
  }
}

/// Mobile accordion as slivers for embedding in [CustomScrollView].
class CompletedDownloadsSliver extends ConsumerWidget {
  const CompletedDownloadsSliver({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(downloadGroupsProvider);
    final sort = ref.watch(downloadsSortProvider);
    if (groups.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return _MobileCompletedDownloads(groups: groups, sort: sort);
  }
}

class _MobileCompletedDownloads extends ConsumerStatefulWidget {
  final List<DownloadGroup> groups;
  final DownloadsSort sort;

  const _MobileCompletedDownloads({required this.groups, required this.sort});

  @override
  ConsumerState<_MobileCompletedDownloads> createState() =>
      _MobileCompletedDownloadsState();
}

class _MobileCompletedDownloadsState
    extends ConsumerState<_MobileCompletedDownloads> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final totalTracks = widget.groups.fold<int>(
      0,
      (sum, g) => sum + g.tracks.length,
    );
    final totalBytes = widget.groups.fold<int>(
      0,
      (sum, g) => sum + g.totalBytes,
    );

    final byKind = <DownloadGroupKind, List<DownloadGroup>>{};
    for (final g in widget.groups) {
      byKind.putIfAbsent(g.kind, () => []).add(g);
    }

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
                        l10n.downloadCollections,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          l10n.downloadsStats(totalTracks),
                          if (totalBytes > 0) formatDownloadBytes(totalBytes),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                DownloadsSortMenu(currentSort: widget.sort),
              ],
            ),
          ),
        ),
        for (final kind in DownloadGroupKind.values)
          if (byKind[kind] case final section?) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '${downloadGroupSectionTitle(l10n, kind)} · ${section.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final group = section[index];
                  final expanded = _expanded.contains(group.key);
                  return _CollectionAccordionTile(
                    group: group,
                    sort: widget.sort,
                    expanded: expanded,
                    onToggle: () {
                      setState(() {
                        if (expanded) {
                          _expanded.remove(group.key);
                        } else {
                          _expanded.add(group.key);
                        }
                      });
                    },
                  );
                }, childCount: section.length),
              ),
            ),
          ],
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
        ),
      ],
    );
  }
}

class _CollectionAccordionTile extends ConsumerWidget {
  final DownloadGroup group;
  final DownloadsSort sort;
  final bool expanded;
  final VoidCallback onToggle;

  const _CollectionAccordionTile({
    required this.group,
    required this.sort,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final tracks = sortDownloadTracks(group.tracks, sort);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              leading: ThumbnailWidget(
                imageUrl: group.thumbnailUrl,
                size: 48,
                shape: ThumbnailShape.rounded,
              ),
              title: Text(
                group.kind == DownloadGroupKind.singles
                    ? l10n.downloadSingles
                    : group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                [
                  l10n.downloadGroupTrackStats(group.tracks.length),
                  if (group.totalBytes > 0)
                    formatDownloadBytes(group.totalBytes),
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (group.isCollection)
                    IconButton(
                      tooltip: l10n.playAll,
                      icon: const Icon(LucideIcons.play, size: 20),
                      onPressed: () => playDownloadGroup(ref, group),
                      visualDensity: VisualDensity.compact,
                    ),
                  Icon(
                    expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              onTap: onToggle,
              onLongPress:
                  group.isCollection
                      ? () => confirmDeleteDownloadGroup(context, ref, group)
                      : null,
            ),
            if (expanded)
              for (final track in tracks)
                _CompletedTrackTile(download: track, dense: true),
          ],
        ),
      ),
    );
  }
}

class _SplitCompletedDownloads extends ConsumerWidget {
  final List<DownloadGroup> groups;
  final DownloadsSort sort;

  const _SplitCompletedDownloads({required this.groups, required this.sort});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final selectedKey = ref.watch(selectedDownloadGroupKeyProvider);
    DownloadGroup? selected;
    for (final g in groups) {
      if (g.key == selectedKey) {
        selected = g;
        break;
      }
    }
    selected ??= groups.isNotEmpty ? groups.first : null;

    // Keep selection valid when groups change.
    if (selected != null && selected.key != selectedKey) {
      final key = selected.key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedDownloadGroupKeyProvider.notifier).select(key);
      });
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.downloadCollections,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DownloadsSortMenu(currentSort: sort),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final selectedNow = group.key == selected?.key;
                    return _MasterGroupTile(
                      group: group,
                      selected: selectedNow,
                      onTap:
                          () => ref
                              .read(selectedDownloadGroupKeyProvider.notifier)
                              .select(group.key),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        VerticalDivider(
          width: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        Expanded(
          child:
              selected == null
                  ? Center(
                    child: Text(
                      l10n.selectDownloadCollection,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                  : _GroupDetailPane(group: selected, sort: sort),
        ),
      ],
    );
  }
}

class _MasterGroupTile extends StatelessWidget {
  final DownloadGroup group;
  final bool selected;
  final VoidCallback onTap;

  const _MasterGroupTile({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final title =
        group.kind == DownloadGroupKind.singles
            ? l10n.downloadSingles
            : group.name;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color:
            selected
                ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.4)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: ThumbnailWidget(
            imageUrl: group.thumbnailUrl,
            size: 44,
            shape: ThumbnailShape.rounded,
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            [
              downloadGroupSectionTitle(l10n, group.kind),
              l10n.downloadGroupTrackStats(group.tracks.length),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _GroupDetailPane extends ConsumerWidget {
  final DownloadGroup group;
  final DownloadsSort sort;

  const _GroupDetailPane({required this.group, required this.sort});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final tracks = sortDownloadTracks(group.tracks, sort);
    final title =
        group.kind == DownloadGroupKind.singles
            ? l10n.downloadSingles
            : group.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              ThumbnailWidget(
                imageUrl: group.thumbnailUrl,
                size: 56,
                shape: ThumbnailShape.rounded,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        downloadGroupSectionTitle(l10n, group.kind),
                        l10n.downloadGroupTrackStats(group.tracks.length),
                        if (group.totalBytes > 0)
                          formatDownloadBytes(group.totalBytes),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (group.isCollection) ...[
                FilledButton.tonalIcon(
                  onPressed: () => playDownloadGroup(ref, group),
                  icon: const Icon(LucideIcons.play, size: 18),
                  label: Text(l10n.playAll),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: l10n.deleteDownloadCollection,
                  icon: Icon(
                    LucideIcons.trash2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed:
                      () => confirmDeleteDownloadGroup(context, ref, group),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              return _CompletedTrackTile(download: tracks[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _CompletedTrackTile extends ConsumerWidget {
  final DownloadModel download;
  final bool dense;

  const _CompletedTrackTile({required this.download, this.dense = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final subtitleParts = [
      download.artist,
      if (download.fileSize != null) formatDownloadBytes(download.fileSize),
      if (download.downloadedAt != null)
        MaterialLocalizations.of(
          context,
        ).formatMediumDate(download.downloadedAt!),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 4, vertical: 2),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: dense ? 12 : 16,
          vertical: dense ? 0 : 2,
        ),
        leading: ThumbnailWidget(
          imageUrl: download.thumbnailUrl,
          size: dense ? 40 : 48,
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
            size: dense ? 20 : 24,
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
              artistsJson: download.artistsJson,
              thumbnailUrl: download.thumbnailUrl,
              isVideo: download.isVideo,
              isExplicit: download.isExplicit,
            ),
      ),
    );
  }
}

Future<void> playDownloadGroup(WidgetRef ref, DownloadGroup group) async {
  if (group.tracks.isEmpty) return;

  final resolve = ref.read(playVideoIdUseCaseProvider);
  final items = <MediaItem>[];
  for (final d in group.tracks) {
    // Single URL entry point: local download if present, else stream (throws
    // offline when neither is available).
    final String url;
    try {
      url = await resolve.resolveUrl(d.videoId);
    } catch (_) {
      continue;
    }
    items.add(
      QueueTrack(
        videoId: d.videoId,
        url: url,
        isVideo: d.isVideo,
        isExplicit: d.isExplicit,
        artistsJson: d.artistsJson,
        title: d.title,
        artist: d.artist,
        artUri:
            d.thumbnailUrl != null && d.thumbnailUrl!.isNotEmpty
                ? Uri.parse(d.thumbnailUrl!)
                : null,
      ).toFreshMediaItem(),
    );
  }
  if (items.isEmpty) return;
  await ref.read(playerStateProvider.notifier).playNow(items);
}

Future<void> confirmDeleteDownloadGroup(
  BuildContext context,
  WidgetRef ref,
  DownloadGroup group,
) async {
  final l10n = AppLocalizations.of(context)!;
  final name =
      group.kind == DownloadGroupKind.singles
          ? l10n.downloadSingles
          : group.name;
  final confirm = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(l10n.deleteDownloadCollection),
          content: Text(
            l10n.deleteDownloadCollectionConfirm(group.tracks.length, name),
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
  if (confirm != true) return;
  final notifier = ref.read(activeDownloadsProvider.notifier);
  for (final track in group.tracks) {
    await notifier.deleteDownload(track.videoId);
  }
}

class DownloadsSortMenu extends ConsumerWidget {
  final DownloadsSort currentSort;

  const DownloadsSortMenu({super.key, required this.currentSort});

  Map<DownloadsSort, String> _options(AppLocalizations l10n) => {
    DownloadsSort.newest: l10n.sortNewest,
    DownloadsSort.title: l10n.sortByTitle,
    DownloadsSort.largest: l10n.sortBySize,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final label = _options(l10n)[currentSort]!;
    final isMobile = MediaQuery.of(context).size.width < kCompactBreakpoint;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    if (isMobile) {
      return TextButton.icon(
        onPressed: () => _showSortBottomSheet(context, ref),
        icon: const Icon(LucideIcons.arrowUpDown, size: 16),
        label: Text(label, style: labelStyle),
      );
    }

    return PopupMenuButton<DownloadsSort>(
      tooltip: l10n.sortDownloads,
      initialValue: currentSort,
      onSelected:
          (value) => ref.read(downloadsSortProvider.notifier).update(value),
      itemBuilder:
          (context) => [
            for (final entry in _options(l10n).entries)
              PopupMenuItem<DownloadsSort>(
                value: entry.key,
                child: Text(entry.value),
              ),
          ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.arrowUpDown, size: 16),
            const SizedBox(width: 8),
            Text(label, style: labelStyle),
          ],
        ),
      ),
    );
  }

  void _showSortBottomSheet(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final options = _options(l10n);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  l10n.sortBy,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              RadioGroup<DownloadsSort>(
                groupValue: currentSort,
                onChanged: (value) {
                  if (value == null) return;
                  ref.read(downloadsSortProvider.notifier).update(value);
                  Navigator.pop(sheetContext);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in options.entries)
                      ListTile(
                        leading: Icon(
                          entry.key == currentSort ? LucideIcons.check : null,
                          color: Theme.of(sheetContext).colorScheme.primary,
                        ),
                        title: Text(
                          entry.value,
                          style: TextStyle(
                            fontWeight:
                                entry.key == currentSort
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color:
                                entry.key == currentSort
                                    ? Theme.of(sheetContext).colorScheme.primary
                                    : null,
                          ),
                        ),
                        trailing: Radio<DownloadsSort>(value: entry.key),
                        onTap: () {
                          ref
                              .read(downloadsSortProvider.notifier)
                              .update(entry.key);
                          Navigator.pop(sheetContext);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

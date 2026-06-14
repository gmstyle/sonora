import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/player_colors.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/playlist_cover_collage.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import 'create_playlist_dialog.dart';
import '../providers/library_provider.dart';

// ── Top-level responsive dispatcher ───────────────────────────────────────────

class PlaylistDetailView extends ConsumerWidget {
  final LocalPlaylistModel playlist;
  final VoidCallback onUpdated;

  const PlaylistDetailView({
    super.key,
    required this.playlist,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kCompactBreakpoint) {
          return _PlaylistDetailMobileLayout(
            playlist: playlist,
            onUpdated: onUpdated,
          );
        } else if (constraints.maxWidth < kExpandedBreakpoint) {
          return _PlaylistDetailTabletLayout(
            playlist: playlist,
            onUpdated: onUpdated,
          );
        } else {
          return _PlaylistDetailWideLayout(
            playlist: playlist,
            onUpdated: onUpdated,
          );
        }
      },
    );
  }
}

// ── Layout variants ──────────────────────────────────────────────────────────

class _PlaylistDetailMobileLayout extends ConsumerWidget {
  final LocalPlaylistModel playlist;
  final VoidCallback onUpdated;

  const _PlaylistDetailMobileLayout({
    required this.playlist,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PlaylistDetailContent(
      playlist: playlist,
      onUpdated: onUpdated,
      isTablet: false,
      isWide: false,
    );
  }
}

class _PlaylistDetailTabletLayout extends ConsumerWidget {
  final LocalPlaylistModel playlist;
  final VoidCallback onUpdated;

  const _PlaylistDetailTabletLayout({
    required this.playlist,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PlaylistDetailContent(
      playlist: playlist,
      onUpdated: onUpdated,
      isTablet: true,
      isWide: false,
    );
  }
}

class _PlaylistDetailWideLayout extends ConsumerWidget {
  final LocalPlaylistModel playlist;
  final VoidCallback onUpdated;

  const _PlaylistDetailWideLayout({
    required this.playlist,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PlaylistDetailContent(
      playlist: playlist,
      onUpdated: onUpdated,
      isTablet: false,
      isWide: true,
    );
  }
}

// ── Main content ─────────────────────────────────────────────────────────────

class _PlaylistDetailContent extends ConsumerStatefulWidget {
  final LocalPlaylistModel playlist;
  final VoidCallback onUpdated;
  final bool isTablet;
  final bool isWide;

  const _PlaylistDetailContent({
    required this.playlist,
    required this.onUpdated,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  ConsumerState<_PlaylistDetailContent> createState() =>
      _PlaylistDetailContentState();
}

class _PlaylistDetailContentState
    extends ConsumerState<_PlaylistDetailContent> {
  late final ScrollController _scrollController;
  double _scrollProgress = 0.0;
  List<PlaylistEntryModel>? _localEntries;
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double expandedHeight =
        widget.isTablet || widget.isWide ? 360.0 : 300.0;
    final double collapsedHeight =
        kToolbarHeight + MediaQuery.of(context).padding.top;
    final double delta = expandedHeight - collapsedHeight;
    final double progress = (_scrollController.offset / delta).clamp(0.0, 1.0);
    if (progress != _scrollProgress) {
      setState(() {
        _scrollProgress = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(playlistEntriesProvider(widget.playlist.id));
    final likedAsync = ref.watch(likedSongsProvider);
    final allPlaylistsAsync = ref.watch(playlistsProvider);

    // Sync local state with provider data when new data is loaded
    if (entriesAsync.hasValue && !_isReordering) {
      final dbEntries = entriesAsync.value!;
      if (_localEntries == null ||
          _localEntries!.length != dbEntries.length ||
          !entriesAsync.isLoading) {
        _localEntries = List<PlaylistEntryModel>.from(dbEntries);
      }
    }

    final entries =
        _localEntries ?? entriesAsync.asData?.value ?? <PlaylistEntryModel>[];
    final likedSongs = likedAsync.asData?.value ?? <LikedSongModel>[];
    final allPlaylists =
        allPlaylistsAsync.asData?.value ?? <LocalPlaylistModel>[];
    final freshPlaylist =
        allPlaylists.where((p) => p.id == widget.playlist.id).firstOrNull ??
        widget.playlist;

    final thumbnailUrls =
        entries
            .map((e) {
              final liked = _findLiked(likedSongs, e.videoId);
              return liked?.thumbnailUrl ?? e.thumbnailUrl;
            })
            .where((u) => u != null && u.isNotEmpty)
            .cast<String>()
            .take(3)
            .toList();

    final bottomPad = widget.isWide ? 48.0 : 16.0;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _LocalPlaylistSliverAppBar(
            playlist: freshPlaylist,
            thumbnailUrls: thumbnailUrls,
            entryCount: entries.length,
            scrollProgress: _scrollProgress,
            isTablet: widget.isTablet,
            isWide: widget.isWide,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _LocalPlaylistActions(
                playlist: widget.playlist,
                entries: entries,
                likedSongs: likedSongs,
                onPlayAll: entries.isNotEmpty ? () => _playAll() : null,
                onShuffle: entries.isNotEmpty ? () => _shufflePlay() : null,
                onAddToQueue: entries.isNotEmpty ? () => _addToQueue() : null,
                onDownload: entries.isNotEmpty ? () => _downloadAll() : null,
                onRename: () => _renamePlaylist(),
                isTabletOrWide: widget.isTablet || widget.isWide,
              ),
            ),
          ),

          ...entriesAsync.when<List<Widget>>(
            loading:
                () => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
                      child: _entryShimmerList(),
                    ),
                  ),
                ],
            error:
                (e, _) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
                      child: ErrorRetryWidget(
                        message:
                            AppLocalizations.of(
                              context,
                            )!.failedToLoadPlaylistEntries,
                        onRetry:
                            () => ref.invalidate(
                              playlistEntriesProvider(widget.playlist.id),
                            ),
                      ),
                    ),
                  ),
                ],
            data: (loadedEntries) {
              final displayEntries = _localEntries ?? loadedEntries;
              if (displayEntries.isEmpty) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
                      child: EmptyStateWidget(
                        icon: LucideIcons.listVideo,
                        title: AppLocalizations.of(context)!.emptyPlaylist,
                        body: AppLocalizations.of(context)!.emptyPlaylistHint,
                      ),
                    ),
                  ),
                ];
              }

              return [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
                  sliver: SliverReorderableList(
                    itemCount: displayEntries.length,
                    proxyDecorator:
                        (child, index, animation) =>
                            Material(color: Colors.transparent, child: child),
                    itemBuilder: (context, index) {
                      final entry = displayEntries[index];
                      final liked = _findLiked(likedSongs, entry.videoId);
                      return _PlaylistEntryTile(
                        key: ValueKey('${entry.playlistId}-${entry.videoId}'),
                        index: index,
                        entry: entry,
                        liked: liked,
                        onTap: () => _playFrom(displayEntries, index),
                        onRemove: () => _removeEntry(entry),
                      );
                    },
                    onReorderItem:
                        (oldIndex, newIndex) =>
                            _reorder(displayEntries, oldIndex, newIndex),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  LikedSongModel? _findLiked(List<LikedSongModel> songs, String videoId) {
    for (final s in songs) {
      if (s.videoId == videoId) return s;
    }
    return null;
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _playAll() async {
    final l10n = AppLocalizations.of(context)!;
    ref
        .read(actionFeedbackProvider.notifier)
        .report(l10n.playingPlaylist(widget.playlist.name));
    try {
      final entries = await ref.read(
        playlistEntriesProvider(widget.playlist.id).future,
      );
      await _buildMediaItemsAndPlay(entries, startIndex: 0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToPlayPlaylist(e.toString()))),
      );
    }
  }

  Future<void> _shufflePlay() async {
    final l10n = AppLocalizations.of(context)!;
    ref
        .read(actionFeedbackProvider.notifier)
        .report(l10n.shufflingPlaylist(widget.playlist.name));
    try {
      final entries = await ref.read(
        playlistEntriesProvider(widget.playlist.id).future,
      );
      final shuffled = List<PlaylistEntryModel>.from(entries)..shuffle();
      await _buildMediaItemsAndPlay(shuffled, startIndex: 0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToPlayPlaylist(e.toString()))),
      );
    }
  }

  Future<void> _playFrom(List<PlaylistEntryModel> entries, int index) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _buildMediaItemsAndPlay(entries, startIndex: index);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.failedToPlay(e.toString()))));
    }
  }

  Future<void> _addToQueue() async {
    final player = ref.read(playerStateProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    try {
      final entries = await ref.read(
        playlistEntriesProvider(widget.playlist.id).future,
      );
      final items = await ref
          .read(libraryNotifierProvider.notifier)
          .buildLocalPlaylistItems(entries);
      if (items.isNotEmpty) await player.addAllToQueue(items);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.addedToQueue(items.length))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToAddToQueue(e.toString()))),
      );
    }
  }

  Future<void> _downloadAll() async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(activeDownloadsProvider.notifier);
    final likedSongs = await ref.read(likedSongsProvider.future);
    final alreadyDownloadedIds = ref.read(downloadedIdsProvider);

    final entries = await ref.read(
      playlistEntriesProvider(widget.playlist.id).future,
    );
    final toDownload =
        entries
            .where((e) => !alreadyDownloadedIds.contains(e.videoId))
            .toList();

    if (toDownload.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.allSongsAlreadyDownloading)));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.downloadingSongs(toDownload.length, widget.playlist.name),
        ),
      ),
    );

    for (final entry in toDownload) {
      final liked = _findLiked(likedSongs, entry.videoId);
      final title = liked?.title ?? entry.title ?? entry.videoId;
      final artist = liked?.artist ?? entry.artist ?? '';
      final thumbnailUrl = liked?.thumbnailUrl ?? entry.thumbnailUrl;
      await notifier.startDownload(
        videoId: entry.videoId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
        subdirectory: widget.playlist.name,
      );
    }
  }

  Future<void> _renamePlaylist() async {
    final allPlaylists =
        ref.read(playlistsProvider).asData?.value ?? <LocalPlaylistModel>[];
    final fresh =
        allPlaylists.where((p) => p.id == widget.playlist.id).firstOrNull ??
        widget.playlist;

    final result = await showDialog<String>(
      context: context,
      builder:
          (_) => CreatePlaylistDialog(
            initialName: fresh.name,
            title: AppLocalizations.of(context)!.renamePlaylist,
          ),
    );
    if (result != null && result.isNotEmpty && result != fresh.name) {
      await ref
          .read(libraryNotifierProvider.notifier)
          .updatePlaylist(widget.playlist.id, name: result);
      ref.invalidate(playlistsProvider);
      widget.onUpdated();
    }
  }

  Future<void> _removeEntry(PlaylistEntryModel entry) async {
    await ref
        .read(libraryNotifierProvider.notifier)
        .removeEntry(entry.playlistId, entry.videoId);
    ref.invalidate(playlistEntriesProvider(widget.playlist.id));
    widget.onUpdated();
  }

  Future<void> _reorder(
    List<PlaylistEntryModel> entries,
    int oldIndex,
    int newIndex,
  ) async {
    if (_localEntries == null) return;

    setState(() {
      _isReordering = true;
      final moved = _localEntries!.removeAt(oldIndex);
      _localEntries!.insert(newIndex, moved);
    });

    try {
      await ref
          .read(libraryNotifierProvider.notifier)
          .reorderPlaylistEntries(widget.playlist.id, _localEntries!);
      ref.invalidate(playlistEntriesProvider(widget.playlist.id));
      await ref.read(playlistEntriesProvider(widget.playlist.id).future);
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isReordering = false;
        });
      }
    }
  }

  Future<void> _buildMediaItemsAndPlay(
    List<PlaylistEntryModel> entries, {
    required int startIndex,
  }) async {
    final player = ref.read(playerStateProvider.notifier);
    final items = await ref
        .read(libraryNotifierProvider.notifier)
        .buildLocalPlaylistItems(entries);
    await player.playNow(items, initialIndex: startIndex);
  }
}

// ── SliverAppBar ─────────────────────────────────────────────────────────────

class _LocalPlaylistSliverAppBar extends StatelessWidget {
  final LocalPlaylistModel playlist;
  final List<String> thumbnailUrls;
  final int entryCount;
  final double scrollProgress;
  final bool isTablet;
  final bool isWide;

  const _LocalPlaylistSliverAppBar({
    required this.playlist,
    required this.thumbnailUrls,
    required this.entryCount,
    required this.scrollProgress,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: isTablet || isWide ? 360 : 300,
      pinned: true,
      iconTheme: const IconThemeData(color: Colors.white),
      foregroundColor: Colors.white,
      title: AnimatedOpacity(
        opacity: scrollProgress > 0.8 ? (scrollProgress - 0.8) / 0.2 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Text(
          playlist.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailUrls.isNotEmpty)
              Hero(
                tag: 'local_playlist_art_${playlist.id}',
                child: PlaylistCoverCollage(
                  thumbnailUrls: thumbnailUrls,
                  borderRadius: 0,
                ),
              )
            else
              _placeholder(context),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
            _artworkTopScrim(context),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Opacity(
                opacity: (1.0 - scrollProgress * 1.5).clamp(0.0, 1.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: PlayerColors.of(context).titlePrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (playlist.description != null &&
                        playlist.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        playlist.description!,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: PlayerColors.of(context).titleSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.videoCount(entryCount),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: PlayerColors.of(context).labelMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Icon(
      LucideIcons.listVideo,
      size: 80,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

Widget _artworkTopScrim(BuildContext context) {
  final pc = PlayerColors.of(context);
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.20, 0.32],
        colors: [pc.topScrimStart, pc.topScrimMid, Colors.transparent],
      ),
    ),
  );
}

// ── Actions ───────────────────────────────────────────────────────────────────

class _LocalPlaylistActions extends ConsumerWidget {
  final LocalPlaylistModel playlist;
  final List<PlaylistEntryModel> entries;
  final List<LikedSongModel> likedSongs;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onDownload;
  final VoidCallback? onRename;
  final bool isTabletOrWide;

  const _LocalPlaylistActions({
    required this.playlist,
    required this.entries,
    required this.likedSongs,
    this.onPlayAll,
    this.onShuffle,
    this.onAddToQueue,
    this.onDownload,
    this.onRename,
    this.isTabletOrWide = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isTabletOrWide) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.download),
                  onPressed: onDownload,
                  tooltip: AppLocalizations.of(context)!.downloadPlaylist,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.listMusic),
                  onPressed: onAddToQueue,
                  tooltip: AppLocalizations.of(context)!.addToQueue,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.shuffle),
                  onPressed: onShuffle,
                  tooltip: AppLocalizations.of(context)!.shuffle,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.pencil),
                  onPressed: onRename,
                  tooltip: AppLocalizations.of(context)!.renamePlaylist,
                ),
              ],
            ),
            SizedBox(
              width: 56,
              height: 56,
              child: FilledButton(
                onPressed: onPlayAll,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(LucideIcons.play, size: 28),
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: onPlayAll,
          icon: const Icon(LucideIcons.play),
          label: Text(AppLocalizations.of(context)!.playAll),
        ),
        FilledButton.icon(
          onPressed: onShuffle,
          icon: const Icon(LucideIcons.shuffle),
          label: Text(AppLocalizations.of(context)!.shufflePlay),
        ),
        FilledButton.tonalIcon(
          onPressed: onAddToQueue,
          icon: const Icon(LucideIcons.listMusic),
          label: Text(AppLocalizations.of(context)!.addToQueue),
        ),
        FilledButton.tonalIcon(
          onPressed: onDownload,
          icon: const Icon(LucideIcons.download),
          label: Text(AppLocalizations.of(context)!.downloadPlaylist),
        ),
        FilledButton.tonalIcon(
          onPressed: onRename,
          icon: const Icon(LucideIcons.pencil),
          label: Text(AppLocalizations.of(context)!.renamePlaylist),
        ),
      ],
    );
  }
}

// ── Entry tile ────────────────────────────────────────────────────────────────

class _PlaylistEntryTile extends ConsumerWidget {
  final int index;
  final PlaylistEntryModel entry;
  final LikedSongModel? liked;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PlaylistEntryTile({
    super.key,
    required this.index,
    required this.entry,
    this.liked,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = liked?.title ?? entry.title ?? 'Video #${entry.videoId}';
    final artist = liked?.artist ?? entry.artist ?? '';
    final thumbnailUrl = liked?.thumbnailUrl ?? entry.thumbnailUrl;
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final isDownloaded = downloadedIds.contains(entry.videoId);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  LucideIcons.gripVertical,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            ThumbnailWidget(
              imageUrl: thumbnailUrl,
              size: 48,
              shape: ThumbnailShape.rounded,
            ),
          ],
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle:
            artist.isNotEmpty
                ? Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                )
                : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDownloaded)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  LucideIcons.checkCircle,
                  size: 16,
                  color: cs.primary,
                ),
              ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 18),
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              color: cs.onSurfaceVariant,
              tooltip: AppLocalizations.of(context)!.remove,
            ),
          ],
        ),
        onTap: onTap,
        onLongPress:
            () => ContextMenuSheet.showForSong(
              context,
              videoId: entry.videoId,
              title: title,
              artist: artist,
              thumbnailUrl: thumbnailUrl,
              isVideo: true,
            ),
      ),
    );
  }
}

// ── Loading shimmer ───────────────────────────────────────────────────────────

Widget _entryShimmerList() => Column(
  children: List.generate(
    6,
    (_) => const Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: ShimmerLoading(variant: ShimmerVariant.tile),
    ),
  ),
);

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/player_colors.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/playlist_cover_collage.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../../shared/widgets/video_badge.dart';
import '../../../shared/widgets/glass_app_bar_background.dart';
import '../../../shared/widgets/detail_actions_bar.dart';
import '../../../shared/widgets/detail_download_button.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import 'linked_playlist_actions.dart';
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
        widget.isTablet || widget.isWide ? 360.0 : 340.0;
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
    final downloadedIds = ref.watch(downloadedIdsProvider);

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

    final bottomPad =
        (widget.isWide ? 48.0 : 16.0) + MediaQuery.of(context).padding.bottom;

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
                playlist: freshPlaylist,
                entryVideoIds: entries.map((e) => e.videoId).toList(),
                onPlayAll: entries.isNotEmpty ? () => _playAll() : null,
                onShuffle: entries.isNotEmpty ? () => _shufflePlay() : null,
                onAddToQueue: entries.isNotEmpty ? () => _addToQueue() : null,
                onDownload:
                    entries.isNotEmpty && !ref.watch(isOfflineProvider)
                        ? () => _downloadAll()
                        : null,
                onUpdated: widget.onUpdated,
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
                      final title =
                          liked?.title ??
                          entry.title ??
                          'Video #${entry.videoId}';
                      final artist = liked?.artist ?? entry.artist ?? '';
                      final thumbnailUrl =
                          liked?.thumbnailUrl ?? entry.thumbnailUrl;
                      final isExplicit = liked?.isExplicit ?? entry.isExplicit;
                      final duration = liked?.duration ?? entry.duration;

                      return SongTile(
                        key: ValueKey(
                          '${entry.playlistId}-${entry.videoId}-${entry.position}',
                        ),
                        videoId: entry.videoId,
                        title: title,
                        artist: artist,
                        thumbnailUrl: thumbnailUrl,
                        duration: duration,
                        isExplicit: isExplicit,
                        isVideo: entry.isVideo,
                        artistId: liked?.artistId,
                        albumId: liked?.albumId,
                        artistsJson: liked?.artistsJson ?? entry.artistsJson,
                        onTap: () => _playSong(displayEntries, index),
                        leadingOverride: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  LucideIcons.gripVertical,
                                  size: 20,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Stack(
                              children: [
                                ThumbnailWidget(
                                  imageUrl: thumbnailUrl,
                                  size: 48,
                                  shape: ThumbnailShape.rounded,
                                ),
                                if (entry.isVideo)
                                  Positioned(
                                    bottom: 0,
                                    right:
                                        downloadedIds.contains(entry.videoId)
                                            ? null
                                            : 0,
                                    left:
                                        downloadedIds.contains(entry.videoId)
                                            ? 0
                                            : null,
                                    child: const VideoBadge(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 3,
                                        vertical: 1,
                                      ),
                                      borderRadius: 3,
                                    ),
                                  ),
                                if (downloadedIds.contains(entry.videoId))
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        LucideIcons.checkCircle,
                                        size: 10,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        trailingActions: [
                          IconButton(
                            icon: const Icon(LucideIcons.x, size: 18),
                            onPressed: () => _removeEntry(entry),
                            visualDensity: VisualDensity.compact,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            tooltip: AppLocalizations.of(context)!.remove,
                          ),
                        ],
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

  Future<void> _playSong(List<PlaylistEntryModel> entries, int index) async {
    final l10n = AppLocalizations.of(context)!;
    final player = ref.read(playerStateProvider.notifier);
    final entry = entries[index];
    try {
      await player.playVideoId(
        entry.videoId,
        isVideo: entry.isVideo,
        isExplicit: entry.isExplicit,
      );
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
          .buildLocalPlaylistItems(entries, playIndex: -1);
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
            .where((e) => !notifier.isDownloading(e.videoId))
            .toList();

    if (toDownload.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.allSongsAlreadyDownloading)));
      return;
    }

    final batchId = 'localPlaylist:${widget.playlist.id}';
    final batchTotal = toDownload.length;

    for (final entry in toDownload) {
      final liked = _findLiked(likedSongs, entry.videoId);
      final title = liked?.title ?? entry.title ?? entry.videoId;
      final artist = liked?.artist ?? entry.artist ?? '';
      final thumbnailUrl = liked?.thumbnailUrl ?? entry.thumbnailUrl;
      final isExplicit = liked?.isExplicit ?? entry.isExplicit;
      unawaited(
        notifier.startDownload(
          videoId: entry.videoId,
          title: title,
          artist: artist,
          artistsJson: liked?.artistsJson ?? entry.artistsJson,
          thumbnailUrl: thumbnailUrl,
          subdirectory: widget.playlist.name,
          isExplicit: isExplicit,
          isVideo: liked?.isVideo ?? entry.isVideo,
          batchId: batchId,
          batchName: widget.playlist.name,
          batchTotal: batchTotal,
        ),
      );
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
        .buildLocalPlaylistItems(entries, playIndex: startIndex);
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
    final theme = Theme.of(context);
    final iconColor = Color.lerp(
      Colors.white,
      theme.colorScheme.onSurface,
      scrollProgress,
    );

    return SliverAppBar(
      expandedHeight: isTablet || isWide ? 360 : 340,
      pinned: true,
      iconTheme: IconThemeData(color: iconColor),
      foregroundColor: iconColor,
      title: AnimatedOpacity(
        opacity: scrollProgress > 0.8 ? (scrollProgress - 0.8) / 0.2 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Text(
          playlist.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
      ),
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          GlassAppBarBackground(opacity: scrollProgress),
          FlexibleSpaceBar(background: _buildHeaderBackground(context)),
        ],
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

  Widget _buildHeaderBackground(BuildContext context) {
    final isTabletOrWide = isTablet || isWide;
    final theme = Theme.of(context);
    final colors = PlayerColors.of(context);

    if (!isTabletOrWide) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrls.isNotEmpty)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Opacity(
                  opacity: 0.4,
                  child: PlaylistCoverCollage(
                    thumbnailUrls: thumbnailUrls,
                    borderRadius: 0,
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  theme.colorScheme.surface.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
          _artworkTopScrim(context),
          Positioned(
            top: 56 + MediaQuery.of(context).padding.top,
            bottom: 12,
            left: 24,
            right: 24,
            child: Opacity(
              opacity: (1.0 - scrollProgress * 1.5).clamp(0.0, 1.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (thumbnailUrls.isNotEmpty)
                    Hero(
                      tag: 'local_playlist_art_${playlist.id}',
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: PlaylistCoverCollage(
                            thumbnailUrls: thumbnailUrls,
                            borderRadius: 12,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: Icon(
                        LucideIcons.listVideo,
                        size: 60,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    playlist.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.titlePrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (playlist.isLinked) ...[
                    const SizedBox(height: 6),
                    LinkedPlaylistBadge(playlist: playlist),
                    if (playlist.sourceKind == 'spotify') ...[
                      const SizedBox(height: 6),
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.playlistSyncSpotifyRateLimitHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.labelMuted,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ] else if (playlist.description != null &&
                      playlist.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      playlist.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.titleSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context)!.videoCount(entryCount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.labelMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (thumbnailUrls.isNotEmpty)
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Opacity(
                opacity: 0.35,
                child: PlaylistCoverCollage(
                  thumbnailUrls: thumbnailUrls,
                  borderRadius: 0,
                ),
              ),
            ),
          )
        else
          Positioned.fill(
            child: Container(color: theme.colorScheme.surfaceContainerHighest),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                theme.colorScheme.surface.withValues(alpha: 0.95),
              ],
            ),
          ),
        ),
        _artworkTopScrim(context),
        Positioned(
          top: 80 + MediaQuery.of(context).padding.top,
          bottom: 24,
          left: isWide ? 40 : 24,
          right: isWide ? 40 : 24,
          child: Opacity(
            opacity: (1.0 - scrollProgress * 1.5).clamp(0.0, 1.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (thumbnailUrls.isNotEmpty)
                  Hero(
                    tag: 'local_playlist_art_${playlist.id}',
                    child: Container(
                      width: isWide ? 190 : 150,
                      height: isWide ? 190 : 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: PlaylistCoverCollage(
                          thumbnailUrls: thumbnailUrls,
                          borderRadius: 16,
                        ),
                      ),
                    ),
                  )
                else
                  _placeholder(context),
                const SizedBox(width: 28),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        playlist.isLinked
                            ? AppLocalizations.of(
                              context,
                            )!.linkedBadge.toUpperCase()
                            : 'PLAYLIST',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.5,
                          color: colors.labelMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        playlist.name,
                        style: (isWide
                                ? theme.textTheme.headlineLarge
                                : theme.textTheme.headlineMedium)
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.titlePrimary,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      if (playlist.isLinked) ...[
                        LinkedPlaylistBadge(playlist: playlist),
                        if (playlist.sourceKind == 'spotify') ...[
                          const SizedBox(height: 6),
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.playlistSyncSpotifyRateLimitHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.labelMuted,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                      ] else if (playlist.description != null &&
                          playlist.description!.isNotEmpty) ...[
                        Text(
                          playlist.description!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.titleSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        AppLocalizations.of(context)!.videoCount(entryCount),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.subtitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
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

class _LocalPlaylistActions extends StatelessWidget {
  final LocalPlaylistModel playlist;
  final List<String> entryVideoIds;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onDownload;
  final VoidCallback onUpdated;

  const _LocalPlaylistActions({
    required this.playlist,
    required this.entryVideoIds,
    required this.onUpdated,
    this.onPlayAll,
    this.onShuffle,
    this.onAddToQueue,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final secondary = rankDetailActions([
      DetailAction(
        id: DetailActionId.queue,
        icon: LucideIcons.listMusic,
        label: l10n.addToQueue,
        tooltip: l10n.addToQueue,
        onPressed: onAddToQueue,
      ),
      DetailAction(
        id: DetailActionId.download,
        icon: LucideIcons.download,
        label: l10n.downloadPlaylist,
        tooltip: l10n.downloadPlaylist,
        onPressed: onDownload,
        buildControl:
            (context, compact) => _LocalPlaylistDownloadButton(
              playlistId: playlist.id,
              entryVideoIds: entryVideoIds,
              idleLabel: l10n.downloadPlaylist,
              onDownload: onDownload,
              iconOnly: compact,
            ),
      ),
    ]);

    return DetailActionsBar(
      secondary: secondary,
      onPlay: onPlayAll,
      playLabel: l10n.playAll,
      onShuffle: onShuffle,
      shuffleLabel: l10n.shufflePlay,
      alwaysShowOverflow: true,
      onOverflow: () {
        ContextMenuSheet.showForCustomPlaylist(
          context,
          playlist: playlist,
          onUpdated: onUpdated,
          hideGoToPlaylist: true,
          omitActionIds: {
            DetailActionId.play,
            DetailActionId.shuffle,
            DetailActionId.queue,
            DetailActionId.download,
          },
        );
      },
    );
  }
}

class _LocalPlaylistDownloadButton extends ConsumerWidget {
  final int playlistId;
  final List<String> entryVideoIds;
  final String idleLabel;
  final VoidCallback? onDownload;
  final bool iconOnly;

  const _LocalPlaylistDownloadButton({
    required this.playlistId,
    required this.entryVideoIds,
    required this.idleLabel,
    required this.onDownload,
    required this.iconOnly,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final batchId = 'localPlaylist:$playlistId';
    final batchActive = ref
        .watch(activeDownloadsProvider)
        .values
        .any(
          (d) =>
              d.batchId == batchId &&
              (d.status == DownloadStatus.pending ||
                  d.status == DownloadStatus.downloading ||
                  d.status == DownloadStatus.error),
        );
    final batch = ref.watch(downloadBatchesProvider)[batchId];
    final downloadedCount = entryVideoIds.where(downloadedIds.contains).length;
    final totalCount = entryVideoIds.length;
    final allDownloaded = totalCount > 0 && downloadedCount == totalCount;
    final state = DetailDownloadButton.resolveState(
      batchActive: batchActive,
      allDownloaded: allDownloaded,
      downloadedCount: downloadedCount,
      totalCount: totalCount,
      batchCompleted: batch?.completed,
      batchTotal: batch?.total,
      idleLabel: idleLabel,
      countLabel: l10n.downloadedCount,
    );
    return DetailDownloadButton(
      iconOnly: iconOnly,
      icon: state.icon,
      label: state.label,
      emphasize: state.emphasize,
      onPressed: state.busy ? null : onDownload,
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

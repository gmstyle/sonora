import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/library_notifier.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../../../shared/widgets/album_card.dart';
import '../../../shared/widgets/playlist_card.dart';
import '../../../shared/widgets/artist_card.dart';
import '../../../shared/widgets/scale_button.dart';
import '../../../providers/settings_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/create_playlist_dialog.dart';
import '../widgets/playlist_detail_view.dart';

class LibraryTabletLayout extends ConsumerStatefulWidget {
  const LibraryTabletLayout({super.key});

  @override
  ConsumerState<LibraryTabletLayout> createState() =>
      _LibraryTabletLayoutState();
}

class _LibraryTabletLayoutState extends ConsumerState<LibraryTabletLayout>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGridView = ref.watch(settingsProvider).isLibraryGridView;
    final isAlbumsOrPlaylists =
        _tabController.index == 2 || _tabController.index == 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.library,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: false,
        actions: [
          if (isAlbumsOrPlaylists)
            IconButton(
              icon: Icon(
                isGridView ? LucideIcons.list : LucideIcons.layoutGrid,
              ),
              tooltip:
                  isGridView
                      ? AppLocalizations.of(context)!.viewList
                      : AppLocalizations.of(context)!.viewGrid,
              onPressed: () {
                ref
                    .read(settingsProvider.notifier)
                    .setLibraryGridView(!isGridView);
              },
            ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavigationRail(
            selectedIndex: _tabController.index,
            onDestinationSelected: (i) => _tabController.animateTo(i),
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: Icon(LucideIcons.heart),
                selectedIcon: Icon(LucideIcons.heart),
                label: Text(AppLocalizations.of(context)!.favorites),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.user),
                selectedIcon: Icon(LucideIcons.user),
                label: Text(AppLocalizations.of(context)!.artists),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.listVideo),
                selectedIcon: Icon(LucideIcons.listVideo),
                label: Text(AppLocalizations.of(context)!.playlists),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.disc),
                selectedIcon: Icon(LucideIcons.disc),
                label: Text(AppLocalizations.of(context)!.albums),
              ),
              NavigationRailDestination(
                icon: Icon(LucideIcons.history),
                selectedIcon: Icon(LucideIcons.history),
                label: Text(AppLocalizations.of(context)!.history),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                if (_tabController.index == 2)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _createPlaylist(context),
                        icon: const Icon(LucideIcons.plus),
                        label: Text(
                          AppLocalizations.of(context)!.createPlaylist,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _FavoritesTab(),
                      _ArtistsTab(),
                      _PlaylistsTab(
                        onPlaylistTap: (playlist) {
                          _showPlaylistDetail(context, ref, playlist);
                        },
                        onCreatePlaylist: () => _createPlaylist(context),
                      ),
                      _AlbumsTab(),
                      _HistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPlaylistDetail(
    BuildContext context,
    WidgetRef ref,
    LocalPlaylistModel playlist,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PlaylistDetailView(
              playlist: playlist,
              onUpdated: () => ref.invalidate(playlistsProvider),
            ),
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const CreatePlaylistDialog(),
    );
    if (result != null && result.isNotEmpty) {
      await ref.read(libraryNotifierProvider.notifier).createPlaylist(result);
      ref.invalidate(playlistsProvider);
    }
  }
}

// ── Favorites Tab ─────────────────────────────────────────────────

class _FavoritesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(likedSongsProvider);
    return async.when(
      loading: () => const _ShimmerSongList(),
      error:
          (e, _) => ErrorRetryWidget(
            message: AppLocalizations.of(context)!.failedToLoadFavorites,
            onRetry: () => ref.invalidate(likedSongsProvider),
          ),
      data: (songs) {
        if (songs.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.heart,
            title: AppLocalizations.of(context)!.noFavoritesYet,
            body: AppLocalizations.of(context)!.noFavoritesHint,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(likedSongsProvider.future),
          child: ListView.builder(
            itemCount: songs.length,
            itemBuilder: (_, i) {
              final s = songs[i];
              return SongTile(
                videoId: s.videoId,
                title: s.title,
                artist: s.artist,
                thumbnailUrl: s.thumbnailUrl,
                artistId: s.artistId,
                albumId: s.albumId,
                isVideo: false,
              );
            },
          ),
        );
      },
    );
  }
}

// ── Artists Tab ───────────────────────────────────────────────────

class _ArtistsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(followedArtistsProvider);
    return async.when(
      loading: () => const _ShimmerArtistList(),
      error:
          (e, _) => ErrorRetryWidget(
            message: AppLocalizations.of(context)!.failedToLoadArtists,
            onRetry: () => ref.invalidate(followedArtistsProvider),
          ),
      data: (artists) {
        if (artists.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.user,
            title: AppLocalizations.of(context)!.noFollowedArtists,
            body: AppLocalizations.of(context)!.noFollowedArtistsHint,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(followedArtistsProvider.future),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140.0,
              childAspectRatio: 0.68,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: artists.length,
            itemBuilder: (_, i) {
              final a = artists[i];
              return ArtistCard(
                artistId: a.artistId,
                name: a.name,
                thumbnailUrl: a.thumbnailUrl,
              );
            },
          ),
        );
      },
    );
  }
}

// ── Playlists Tab ─────────────────────────────────────────────────

class _PlaylistsTab extends ConsumerStatefulWidget {
  final void Function(LocalPlaylistModel playlist) onPlaylistTap;
  final VoidCallback onCreatePlaylist;

  const _PlaylistsTab({
    required this.onPlaylistTap,
    required this.onCreatePlaylist,
  });

  @override
  ConsumerState<_PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends ConsumerState<_PlaylistsTab> {
  @override
  void initState() {
    super.initState();
    Future(
      () =>
          ref
              .read(libraryNotifierProvider.notifier)
              .refreshPlaylistThumbnailsIfNeeded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myAsync = ref.watch(playlistsProvider);
    final likedAsync = ref.watch(likedPlaylistsProvider);
    final isGridView = ref.watch(settingsProvider).isLibraryGridView;

    if (myAsync.isLoading || likedAsync.isLoading) {
      return const _ShimmerPlaylistList();
    }
    if (myAsync.hasError) {
      return ErrorRetryWidget(
        message: AppLocalizations.of(context)!.failedToLoadPlaylists,
        onRetry: () => ref.invalidate(playlistsProvider),
      );
    }
    if (likedAsync.hasError) {
      return ErrorRetryWidget(
        message: AppLocalizations.of(context)!.failedToLoadLikedPlaylists,
        onRetry: () => ref.invalidate(likedPlaylistsProvider),
      );
    }

    final playlists = myAsync.value ?? [];
    final liked = likedAsync.value ?? [];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.myPlaylists,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.plus),
                  tooltip: AppLocalizations.of(context)!.createPlaylist,
                  onPressed: widget.onCreatePlaylist,
                ),
              ],
            ),
          ),
        ),
        if (playlists.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                AppLocalizations.of(context)!.noLocalPlaylistsYet,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else if (isGridView)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170.0,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate((_, i) {
                final p = playlists[i];
                return _LocalPlaylistCard(
                  name: p.name,
                  description: p.description,
                  thumbnailUrl: null,
                  onTap: () => widget.onPlaylistTap(p),
                  onLongPress:
                      () => ContextMenuSheet.showForPlaylist(
                        context,
                        playlistId: p.id.toString(),
                        name: p.name,
                        thumbnailUrl: null,
                      ),
                );
              }, childCount: playlists.length),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              final p = playlists[i];
              return Dismissible(
                key: ValueKey(p.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Theme.of(context).colorScheme.error,
                  child: Icon(
                    LucideIcons.trash2,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
                confirmDismiss: (_) async {
                  return showDialog<bool>(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          title: Text(
                            AppLocalizations.of(context)!.deletePlaylist,
                          ),
                          content: Text(
                            AppLocalizations.of(
                              context,
                            )!.deletePlaylistConfirm(p.name),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(AppLocalizations.of(context)!.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(AppLocalizations.of(context)!.delete),
                            ),
                          ],
                        ),
                  );
                },
                onDismissed: (_) async {
                  await ref
                      .read(libraryNotifierProvider.notifier)
                      .deletePlaylist(p.id);
                  ref.invalidate(playlistsProvider);
                },
                child: ListTile(
                  leading: const Icon(LucideIcons.listVideo),
                  title: Text(p.name),
                  subtitle:
                      p.description != null && p.description!.isNotEmpty
                          ? Text(
                            p.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                          : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.pencil),
                        onPressed: () => _renamePlaylist(context, ref, p),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.trash2),
                        onPressed: () => _deletePlaylist(context, ref, p),
                      ),
                      const Icon(LucideIcons.chevronRight),
                    ],
                  ),
                  onTap: () => widget.onPlaylistTap(p),
                ),
              );
            }, childCount: playlists.length),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              AppLocalizations.of(context)!.likedPlaylists,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        if (liked.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                AppLocalizations.of(context)!.likePlaylistHint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else if (isGridView)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170.0,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate((_, i) {
                final p = liked[i];
                return PlaylistCard(
                  playlistId: p.playlistId,
                  name: p.name,
                  thumbnailUrl: p.thumbnailUrl,
                  artist:
                      p.videoCount != null ? '${p.videoCount} videos' : null,
                );
              }, childCount: liked.length),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              final p = liked[i];
              return Dismissible(
                key: ValueKey(p.playlistId),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Theme.of(context).colorScheme.error,
                  child: Icon(
                    LucideIcons.heart,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
                onDismissed: (_) async {
                  await ref
                      .read(libraryNotifierProvider.notifier)
                      .toggleLikedPlaylist(p);
                },
                child: ListTile(
                  leading: ThumbnailWidget(
                    imageUrl: p.thumbnailUrl,
                    size: 48,
                    shape: ThumbnailShape.rounded,
                  ),
                  title: Text(p.name),
                  subtitle:
                      p.videoCount != null
                          ? Text('${p.videoCount} videos')
                          : null,
                  trailing: const Icon(LucideIcons.chevronRight),
                  onTap: () => context.push('/playlist/${p.playlistId}'),
                  onLongPress:
                      () => ContextMenuSheet.showForPlaylist(
                        context,
                        playlistId: p.playlistId,
                        name: p.name,
                        thumbnailUrl: p.thumbnailUrl,
                      ),
                ),
              );
            }, childCount: liked.length),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

Future<void> _deletePlaylist(
  BuildContext context,
  WidgetRef ref,
  LocalPlaylistModel playlist,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.deletePlaylist),
          content: Text(
            AppLocalizations.of(context)!.deletePlaylistConfirm(playlist.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(context)!.delete),
            ),
          ],
        ),
  );
  if (confirm == true) {
    await ref
        .read(libraryNotifierProvider.notifier)
        .deletePlaylist(playlist.id);
    ref.invalidate(playlistsProvider);
  }
}

Future<void> _renamePlaylist(
  BuildContext context,
  WidgetRef ref,
  LocalPlaylistModel playlist,
) async {
  final result = await showDialog<String>(
    context: context,
    builder:
        (_) => CreatePlaylistDialog(
          initialName: playlist.name,
          title: AppLocalizations.of(context)!.renamePlaylist,
        ),
  );
  if (result != null && result.isNotEmpty && result != playlist.name) {
    await ref
        .read(libraryNotifierProvider.notifier)
        .updatePlaylist(playlist.id, name: result);
    ref.invalidate(playlistsProvider);
  }
}

// ── Albums Tab ────────────────────────────────────────────────────

class _AlbumsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(likedAlbumsProvider);
    final isGridView = ref.watch(settingsProvider).isLibraryGridView;

    return async.when(
      loading: () => const _ShimmerSongList(),
      error:
          (e, _) => ErrorRetryWidget(
            message: AppLocalizations.of(context)!.failedToLoadAlbums,
            onRetry: () => ref.invalidate(likedAlbumsProvider),
          ),
      data: (albums) {
        if (albums.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.disc,
            title: AppLocalizations.of(context)!.noLikedAlbums,
            body: AppLocalizations.of(context)!.noLikedAlbumsHint,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(likedAlbumsProvider.future),
          child:
              isGridView
                  ? GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 170.0,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.68,
                        ),
                    itemCount: albums.length,
                    itemBuilder: (context, i) {
                      final a = albums[i];
                      return AlbumCard(
                        albumId: a.albumId,
                        name: a.name,
                        artist: a.artistName,
                        thumbnailUrl: a.thumbnailUrl,
                        year: a.year,
                      );
                    },
                  )
                  : ListView.builder(
                    itemCount: albums.length,
                    itemBuilder: (_, i) {
                      final a = albums[i];
                      return Dismissible(
                        key: ValueKey(a.albumId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: Theme.of(context).colorScheme.error,
                          child: Icon(
                            LucideIcons.heart,
                            color: Theme.of(context).colorScheme.onError,
                          ),
                        ),
                        onDismissed: (_) async {
                          await ref
                              .read(libraryNotifierProvider.notifier)
                              .deleteLikedAlbum(a.albumId);
                        },
                        child: ListTile(
                          leading: ThumbnailWidget(
                            imageUrl: a.thumbnailUrl,
                            size: 48,
                            shape: ThumbnailShape.rounded,
                          ),
                          title: Text(a.name),
                          subtitle: Text(
                            a.year != null
                                ? '${a.artistName} · ${a.year}'
                                : a.artistName,
                          ),
                          trailing: const Icon(LucideIcons.chevronRight),
                          onTap: () => context.push('/album/${a.albumId}'),
                          onLongPress:
                              () => ContextMenuSheet.showForAlbum(
                                context,
                                albumId: a.albumId,
                                name: a.name,
                                artist: a.artistName,
                                thumbnailUrl: a.thumbnailUrl,
                                year: a.year,
                              ),
                        ),
                      );
                    },
                  ),
        );
      },
    );
  }
}

// ── Shimmer Helpers ───────────────────────────────────────────────

class _ShimmerSongList extends StatelessWidget {
  const _ShimmerSongList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (_, _) => const ShimmerLoading(variant: ShimmerVariant.tile),
    );
  }
}

class _ShimmerArtistList extends StatelessWidget {
  const _ShimmerArtistList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemBuilder:
          (_, _) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: ShimmerLoading(variant: ShimmerVariant.tile),
          ),
    );
  }
}

class _ShimmerPlaylistList extends StatelessWidget {
  const _ShimmerPlaylistList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.only(top: 8),
      itemBuilder: (_, _) => const ShimmerLoading(variant: ShimmerVariant.tile),
    );
  }
}

// ── History Tab ───────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(libraryHistoryProvider);
    return async.when(
      loading: () => const _ShimmerSongList(),
      error:
          (e, _) => ErrorRetryWidget(
            message: AppLocalizations.of(context)!.failedToLoadHistory,
            onRetry: () => ref.invalidate(libraryHistoryProvider),
          ),
      data: (history) {
        if (history.isEmpty) {
          return EmptyStateWidget(
            icon: LucideIcons.history,
            title: AppLocalizations.of(context)!.noListeningHistory,
            body: AppLocalizations.of(context)!.noListeningHistoryHint,
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(libraryHistoryProvider.future),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: Text(
                                  AppLocalizations.of(context)!.clearHistory,
                                ),
                                content: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.clearHistoryConfirm,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(
                                      AppLocalizations.of(context)!.cancel,
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(
                                      AppLocalizations.of(context)!.clear,
                                    ),
                                  ),
                                ],
                              ),
                        );
                        if (confirm == true) {
                          await ref
                              .read(libraryNotifierProvider.notifier)
                              .clearHistory();
                          ref.invalidate(libraryHistoryProvider);
                        }
                      },
                      icon: const Icon(LucideIcons.trash2),
                      label: Text(AppLocalizations.of(context)!.clear),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (_, i) {
                    final h = history[i];
                    return SongTile(
                      videoId: h.videoId,
                      title: h.title,
                      artist: h.artist,
                      thumbnailUrl: h.thumbnailUrl,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LocalPlaylistCard extends StatelessWidget {
  final String name;
  final String? description;
  final String? thumbnailUrl;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LocalPlaylistCard({
    required this.name,
    this.description,
    this.thumbnailUrl,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        width: 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ThumbnailWidget(
              imageUrl: thumbnailUrl,
              size: 150,
              shape: ThumbnailShape.rounded,
            ),
            const SizedBox(height: 8),
            Text(
              name,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                description!,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

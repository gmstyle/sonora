import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/models/library_models.dart';
import '../../../providers/library_notifier.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Library', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: false,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NavigationRail(
            selectedIndex: _tabController.index,
            onDestinationSelected: (i) => _tabController.animateTo(i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.favorite_outline),
                selectedIcon: Icon(Icons.favorite),
                label: Text('Favorites'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('Artists'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.playlist_play),
                selectedIcon: Icon(Icons.playlist_play),
                label: Text('Playlists'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.album_outlined),
                selectedIcon: Icon(Icons.album),
                label: Text('Albums'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history),
                selectedIcon: Icon(Icons.history),
                label: Text('History'),
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
                        icon: const Icon(Icons.add),
                        label: const Text('Create Playlist'),
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
            message: 'Failed to load favorites',
            onRetry: () => ref.invalidate(likedSongsProvider),
          ),
      data: (songs) {
        if (songs.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.favorite_outline,
            title: 'No favorites yet',
            body: 'Tap the heart icon on any song to add it here.',
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
            message: 'Failed to load artists',
            onRetry: () => ref.invalidate(followedArtistsProvider),
          ),
      data: (artists) {
        if (artists.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.person_outline,
            title: 'No followed artists',
            body: 'Follow artists from their artist page to see them here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(followedArtistsProvider.future),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: artists.length,
            itemBuilder: (_, i) {
              final a = artists[i];
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push('/artist/${a.artistId}'),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage:
                          a.thumbnailUrl != null
                              ? NetworkImage(a.thumbnailUrl!)
                              : null,
                      child:
                          a.thumbnailUrl == null
                              ? const Icon(Icons.person, size: 48)
                              : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      a.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
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
      () => ref
          .read(libraryNotifierProvider.notifier)
          .refreshPlaylistThumbnailsIfNeeded(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myAsync = ref.watch(playlistsProvider);
    final likedAsync = ref.watch(likedPlaylistsProvider);

    if (myAsync.isLoading || likedAsync.isLoading) {
      return const _ShimmerPlaylistList();
    }
    if (myAsync.hasError) {
      return ErrorRetryWidget(
        message: 'Failed to load playlists',
        onRetry: () => ref.invalidate(playlistsProvider),
      );
    }
    if (likedAsync.hasError) {
      return ErrorRetryWidget(
        message: 'Failed to load liked playlists',
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
                  'My Playlists',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Create Playlist',
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
                'No local playlists yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
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
                    Icons.delete,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
                confirmDismiss: (_) async {
                  return showDialog<bool>(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          title: const Text('Delete playlist'),
                          content: Text(
                            'Are you sure you want to delete "${p.name}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
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
                  leading: const Icon(Icons.playlist_play),
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
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _renamePlaylist(context, ref, p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deletePlaylist(context, ref, p),
                      ),
                      const Icon(Icons.chevron_right),
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
              'Liked Playlists',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        if (liked.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Like a playlist from its page to see it here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
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
                    Icons.favorite,
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
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/playlist/${p.playlistId}'),
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
          title: const Text('Delete playlist'),
          content: Text('Are you sure you want to delete "${playlist.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
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
          title: 'Rename playlist',
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
    return async.when(
      loading: () => const _ShimmerSongList(),
      error:
          (e, _) => ErrorRetryWidget(
            message: 'Failed to load albums',
            onRetry: () => ref.invalidate(likedAlbumsProvider),
          ),
      data: (albums) {
        if (albums.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.album_outlined,
            title: 'No liked albums',
            body: 'Like an album from its page to see it here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(likedAlbumsProvider.future),
          child: ListView.builder(
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
                    Icons.favorite,
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
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/album/${a.albumId}'),
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
      itemBuilder: (_, _) => const Padding(
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
            message: 'Failed to load history',
            onRetry: () => ref.invalidate(libraryHistoryProvider),
          ),
      data: (history) {
        if (history.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.history,
            title: 'No listening history',
            body: 'Your recently played songs will appear here.',
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
                                title: const Text('Clear history'),
                                content: const Text(
                                  'Are you sure you want to clear all listening history?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Clear'),
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
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Clear'),
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

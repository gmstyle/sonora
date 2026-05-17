import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../domain/models/library_models.dart';
import '../../../providers/library_notifier.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/error_retry_widget.dart';
import '../../../shared/widgets/song_tile.dart';
import '../providers/library_provider.dart';
import '../widgets/create_playlist_dialog.dart';
import '../widgets/playlist_detail_view.dart';

class LibraryWideLayout extends ConsumerStatefulWidget {
  const LibraryWideLayout({super.key});

  @override
  ConsumerState<LibraryWideLayout> createState() => _LibraryWideLayoutState();
}

class _LibraryWideLayoutState extends ConsumerState<LibraryWideLayout> {
  int _selectedIndex = 0;

  static const _tabs = ['Favorites', 'Artists', 'Playlists', 'History'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Library', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: false,
      ),
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _createPlaylist(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Playlist'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(_tabs.length, (i) {
                  final icons = [
                    Icons.favorite_outline,
                    Icons.person_outline,
                    Icons.playlist_play,
                    Icons.history,
                  ];
                  return ListTile(
                    selected: i == _selectedIndex,
                    leading: Icon(icons[i]),
                    title: Text(_tabs[i]),
                    onTap: () => setState(() => _selectedIndex = i),
                  );
                }),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _FavoritesTab(),
                  _ArtistsTab(),
                  _PlaylistsTab(
                    onPlaylistTap: (playlist) {
                      _showPlaylistDetail(context, ref, playlist);
                    },
                  ),
                  _HistoryTab(),
                ],
              ),
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
              crossAxisCount: 4,
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

class _PlaylistsTab extends ConsumerWidget {
  final void Function(LocalPlaylistModel playlist) onPlaylistTap;

  const _PlaylistsTab({required this.onPlaylistTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(playlistsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (e, _) => ErrorRetryWidget(
            message: 'Failed to load playlists',
            onRetry: () => ref.invalidate(playlistsProvider),
          ),
      data: (playlists) {
        if (playlists.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.playlist_play,
            title: 'No playlists yet',
            body: 'Create a playlist to organize your music.',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.refresh(playlistsProvider.future),
          child: ListView.builder(
            itemCount: playlists.length,
            padding: const EdgeInsets.only(bottom: 16),
            itemBuilder: (_, i) {
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
                  return await showDialog<bool>(
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
                  onTap: () => onPlaylistTap(p),
                ),
              );
            },
          ),
        );
      },
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
    await ref.read(libraryNotifierProvider.notifier).deletePlaylist(playlist.id);
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

// ── History Tab ───────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(libraryHistoryProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
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
        return Column(
          children: [
            Row(
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
        );
      },
    );
  }
}

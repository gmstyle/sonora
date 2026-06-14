import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../../shared/widgets/artist_tile.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../providers/library_provider.dart';
import 'playlist_detail_view.dart';

class LibrarySearchResultsView extends ConsumerWidget {
  const LibrarySearchResultsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(sortedLikedSongsProvider);
    final artistsAsync = ref.watch(sortedFollowedArtistsProvider);
    final playlistsAsync = ref.watch(sortedPlaylistsProvider);
    final likedPlaylistsAsync = ref.watch(sortedLikedPlaylistsProvider);
    final albumsAsync = ref.watch(sortedLikedAlbumsProvider);
    final historyAsync = ref.watch(sortedHistoryProvider);
    final activeFilter = ref.watch(librarySearchFilterProvider);

    final l10n = AppLocalizations.of(context)!;

    // Check if any provider is still loading
    final isLoading =
        songsAsync.isLoading ||
        artistsAsync.isLoading ||
        playlistsAsync.isLoading ||
        likedPlaylistsAsync.isLoading ||
        albumsAsync.isLoading ||
        historyAsync.isLoading;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final songs = songsAsync.value ?? [];
    final artists = artistsAsync.value ?? [];
    final playlists = playlistsAsync.value ?? [];
    final likedPlaylists = likedPlaylistsAsync.value ?? [];
    final albums = albumsAsync.value ?? [];
    final history = historyAsync.value ?? [];

    final showSongs =
        songs.isNotEmpty &&
        (activeFilter == LibrarySearchFilter.all ||
            activeFilter == LibrarySearchFilter.songs);
    final showArtists =
        artists.isNotEmpty &&
        (activeFilter == LibrarySearchFilter.all ||
            activeFilter == LibrarySearchFilter.artists);
    final showLocalPlaylists =
        playlists.isNotEmpty &&
        (activeFilter == LibrarySearchFilter.all ||
            activeFilter == LibrarySearchFilter.playlists);
    final showLikedPlaylists =
        likedPlaylists.isNotEmpty &&
        (activeFilter == LibrarySearchFilter.all ||
            activeFilter == LibrarySearchFilter.playlists);
    final showAlbums =
        albums.isNotEmpty &&
        (activeFilter == LibrarySearchFilter.all ||
            activeFilter == LibrarySearchFilter.albums);
    final showHistory =
        history.isNotEmpty &&
        (activeFilter == LibrarySearchFilter.all ||
            activeFilter == LibrarySearchFilter.history);

    final totalDisplayedResults =
        (showSongs ? songs.length : 0) +
        (showArtists ? artists.length : 0) +
        (showLocalPlaylists ? playlists.length : 0) +
        (showLikedPlaylists ? likedPlaylists.length : 0) +
        (showAlbums ? albums.length : 0) +
        (showHistory ? history.length : 0);

    if (totalDisplayedResults == 0) {
      return Column(
        children: [
          _buildFilterChips(context, ref, activeFilter),
          Expanded(
            child: EmptyStateWidget(
              icon: LucideIcons.searchX,
              title: l10n.noResults,
              body: l10n.noResultsHint,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildFilterChips(context, ref, activeFilter),
        Expanded(
          child: CustomScrollView(
            slivers: [
              // 1. Favorites Section
              if (showSongs) ...[
                _buildSliverHeader(context, l10n.favorites.toUpperCase()),
                SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final s = songs[i];
                    return SongTile(
                      videoId: s.videoId,
                      title: s.title,
                      artist: s.artist,
                      thumbnailUrl: s.thumbnailUrl,
                      artistId: s.artistId,
                      albumId: s.albumId,
                      isVideo: s.isVideo,
                    );
                  }, childCount: songs.length),
                ),
              ],

              // 2. Artists Section
              if (showArtists) ...[
                _buildSliverHeader(context, l10n.artists.toUpperCase()),
                SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final a = artists[i];
                    return ArtistTile(
                      artistId: a.artistId,
                      name: a.name,
                      thumbnailUrl: a.thumbnailUrl,
                    );
                  }, childCount: artists.length),
                ),
              ],

              // 3. Local Playlists Section
              if (showLocalPlaylists) ...[
                _buildSliverHeader(context, l10n.myPlaylists.toUpperCase()),
                SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final p = playlists[i];
                    return ListTile(
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
                      trailing: const Icon(LucideIcons.chevronRight),
                      onTap: () => _navigateToPlaylist(context, p),
                    );
                  }, childCount: playlists.length),
                ),
              ],

              // 4. Liked Playlists Section
              if (showLikedPlaylists) ...[
                _buildSliverHeader(context, l10n.likedPlaylists.toUpperCase()),
                SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final p = likedPlaylists[i];
                    return ListTile(
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
                    );
                  }, childCount: likedPlaylists.length),
                ),
              ],

              // 5. Albums Section
              if (showAlbums) ...[
                _buildSliverHeader(context, l10n.albums.toUpperCase()),
                SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final a = albums[i];
                    return ListTile(
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
                    );
                  }, childCount: albums.length),
                ),
              ],

              // 6. History Section
              if (showHistory) ...[
                _buildSliverHeader(context, l10n.history.toUpperCase()),
                SliverList(
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final h = history[i];
                    return SongTile(
                      videoId: h.videoId,
                      title: h.title,
                      artist: h.artist,
                      thumbnailUrl: h.thumbnailUrl,
                      isVideo: h.isVideo,
                    );
                  }, childCount: history.length),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    WidgetRef ref,
    LibrarySearchFilter activeFilter,
  ) {
    final l10n = AppLocalizations.of(context)!;

    final filterItems = [
      (LibrarySearchFilter.all, l10n.all),
      (LibrarySearchFilter.songs, l10n.songs),
      (LibrarySearchFilter.artists, l10n.artists),
      (LibrarySearchFilter.playlists, l10n.playlists),
      (LibrarySearchFilter.albums, l10n.albums),
      (LibrarySearchFilter.history, l10n.history),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filterItems.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = filterItems[index];
          final filter = item.$1;
          final label = item.$2;
          final isSelected = filter == activeFilter;

          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                ref.read(librarySearchFilterProvider.notifier).update(filter);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  void _navigateToPlaylist(BuildContext context, LocalPlaylistModel playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PlaylistDetailView(playlist: playlist, onUpdated: () {}),
      ),
    );
  }
}

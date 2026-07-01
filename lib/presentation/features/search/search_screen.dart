import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/extensions/stat_format.dart';

import '../../providers/library_notifier.dart';
import '../../providers/player_provider.dart';
import '../../shared/widgets/album_card.dart';
import '../../shared/widgets/album_tile.dart';
import '../../shared/widgets/artist_card.dart';
import '../../shared/widgets/artist_tile.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/filter_chip_bar.dart';
import '../../shared/widgets/playlist_card.dart';
import '../../shared/widgets/playlist_tile.dart';
import '../../shared/widgets/search_suggestion_tile.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/song_tile.dart';
import '../../shared/widgets/thumbnail_widget.dart';
import '../../shared/widgets/explicit_badge.dart';
import 'providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(searchQueryProvider.notifier).update(query);
  }

  void _submitSearch(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    ref.read(searchQueryProvider.notifier).update(query);
    ref.read(activeSearchQueryProvider.notifier).submit(query);
    _focusNode.unfocus();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).update('');
    ref.read(activeSearchQueryProvider.notifier).update('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final activeQuery = ref.watch(activeSearchQueryProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            autofocus: false,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 16,
              ),
              prefixIcon: const Icon(LucideIcons.search, size: 20),
              suffixIcon:
                  query.isNotEmpty
                      ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 20),
                        onPressed: _clearSearch,
                      )
                      : null,
            ),
            style: Theme.of(context).textTheme.bodyLarge,
            onChanged: _onSearchChanged,
            onSubmitted: _submitSearch,
          ),
        ),
      ),
      body: _buildBody(query, activeQuery),
    );
  }

  Widget _buildBody(String query, String activeQuery) {
    if (query.isEmpty && activeQuery.isEmpty) {
      return _RecentSearches(onTapSearch: _submitSearch);
    }
    if (query.isNotEmpty && query != activeQuery) {
      return _Suggestions(
        query: query,
        onTapSuggestion: _submitSearch,
        onInsertSuggestion: (val) {
          _searchController.text = val;
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: val.length),
          );
          ref.read(searchQueryProvider.notifier).update(val);
          _focusNode.requestFocus();
        },
      );
    }
    return _SearchResults(activeQuery: activeQuery);
  }
}

class _RecentSearches extends ConsumerWidget {
  final ValueChanged<String> onTapSearch;

  const _RecentSearches({required this.onTapSearch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentSearchesProvider);
    return recent.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (searches) {
        if (searches.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.search,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.searchForMusic,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.searchForMusicHint,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                AppLocalizations.of(context)!.recentSearches,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: searches.length,
                itemBuilder: (context, index) {
                  final s = searches[index];
                  return SearchSuggestionTile(
                    query: s.query,
                    isHistory: true,
                    onTap: () => onTapSearch(s.query),
                    onDelete: () async {
                      await ref
                          .read(libraryNotifierProvider.notifier)
                          .deleteSearchEntry(s.query);
                      ref.invalidate(recentSearchesProvider);
                    },
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

class _Suggestions extends ConsumerWidget {
  final String query;
  final ValueChanged<String> onTapSuggestion;
  final ValueChanged<String> onInsertSuggestion;

  const _Suggestions({
    required this.query,
    required this.onTapSuggestion,
    required this.onInsertSuggestion,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(searchSuggestionsProvider);
    return suggestionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (suggestions) {
        if (suggestions.isEmpty) return const SizedBox.shrink();
        return ListView.builder(
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return SearchSuggestionTile(
              query: suggestion,
              isHistory: false,
              onTap: () => onTapSuggestion(suggestion),
              onInsert: () => onInsertSuggestion(suggestion),
            );
          },
        );
      },
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String activeQuery;

  const _SearchResults({required this.activeQuery});

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    VoidCallback? onSeeAll,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                AppLocalizations.of(context)!.showMore,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopResultCard(
    BuildContext context,
    WidgetRef ref,
    SearchResult result,
  ) {
    String title = '';
    String subtitle = '';
    String type = '';
    String? imageUrl;
    VoidCallback? onTap;

    if (result is SongDetailed) {
      title = result.name;
      subtitle = result.artist.name;
      type = AppLocalizations.of(context)!.songs;
      imageUrl =
          result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null;
      onTap =
          () => ref
              .read(playerStateProvider.notifier)
              .playVideoId(
                result.videoId,
                isVideo: false,
                isExplicit: result.isExplicit,
              );
    } else if (result is VideoDetailed) {
      title = result.name;
      subtitle = result.artist.name;
      type = AppLocalizations.of(context)!.videos;
      imageUrl =
          result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null;
      onTap =
          () => ref
              .read(playerStateProvider.notifier)
              .playVideoId(
                result.videoId,
                isVideo: true,
                isExplicit: result.isExplicit,
              );
    } else if (result is ArtistDetailed) {
      title = result.name;
      subtitle =
          result.monthlyListeners != null
              ? (stripYtLabel(result.monthlyListeners) ?? '')
              : '';
      type = AppLocalizations.of(context)!.searchArtists;
      imageUrl =
          result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null;
      onTap = () => context.push('/artist/${result.artistId}');
    } else if (result is AlbumDetailed) {
      title = result.name;
      subtitle = result.artist.name;
      type = AppLocalizations.of(context)!.searchAlbums;
      imageUrl =
          result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null;
      onTap = () => context.push('/album/${result.albumId}');
    } else if (result is PlaylistDetailed) {
      title = result.name;
      subtitle = result.artist.name;
      type = AppLocalizations.of(context)!.searchPlaylists;
      imageUrl =
          result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null;
      onTap = () => context.push('/playlist/${result.playlistId}');
    }

    final bool isCircle = result is ArtistDetailed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              ThumbnailWidget(
                imageUrl: imageUrl,
                size: 72,
                shape:
                    isCircle ? ThumbnailShape.circle : ThumbnailShape.rounded,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        type,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if ((result is SongDetailed && result.isExplicit) ||
                            (result is VideoDetailed && result.isExplicit)) ...[
                          const SizedBox(width: 6),
                          const ExplicitBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                LucideIcons.playCircle,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchFilterProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Column(
      children: [
        FilterChipBar(
          options: [
            AppLocalizations.of(context)!.all,
            AppLocalizations.of(context)!.songs,
            AppLocalizations.of(context)!.searchArtists,
            AppLocalizations.of(context)!.searchAlbums,
            AppLocalizations.of(context)!.searchPlaylists,
          ],
          selectedIndex: filter,
          onSelected:
              (index) => ref.read(searchFilterProvider.notifier).update(index),
        ),
        Expanded(
          child: resultsAsync.when(
            loading:
                () => ListView.builder(
                  itemCount: 6,
                  itemBuilder:
                      (_, _) =>
                          const ShimmerLoading(variant: ShimmerVariant.tile),
                ),
            error:
                (e, _) => ErrorRetryWidget(
                  message: AppLocalizations.of(context)!.searchFailed,
                  onRetry: () => ref.invalidate(searchResultsProvider),
                ),
            data: (results) {
              if (results.isEmpty) {
                return EmptyStateWidget(
                  icon: LucideIcons.searchX,
                  title: AppLocalizations.of(context)!.noResults,
                  body: AppLocalizations.of(context)!.noResultsHint,
                );
              }

              if (filter > 0) {
                // Return a flat list when a specific category is selected
                return ListView.builder(
                  padding: EdgeInsets.only(
                    top: 4,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                  ),
                  itemCount: results.length,
                  itemBuilder:
                      (context, index) =>
                          _buildResultItem(context, ref, results[index]),
                );
              }

              // Categorized structure for the "All" (Tutto) tab:
              final songs = results.whereType<SongDetailed>().toList();
              final videos = results.whereType<VideoDetailed>().toList();
              final artists = results.whereType<ArtistDetailed>().toList();
              final albums = results.whereType<AlbumDetailed>().toList();
              final playlists = results.whereType<PlaylistDetailed>().toList();

              return ListView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                ),
                children: [
                  // 1. Top Result
                  _buildSectionHeader(
                    context,
                    title: AppLocalizations.of(context)!.topResult,
                  ),
                  _buildTopResultCard(context, ref, results.first),

                  // 2. Songs
                  if (songs.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      title: AppLocalizations.of(context)!.songs,
                      onSeeAll:
                          () =>
                              ref.read(searchFilterProvider.notifier).update(1),
                    ),
                    ...songs
                        .take(4)
                        .map((s) => _buildResultItem(context, ref, s)),
                  ],

                  // 3. Videos
                  if (videos.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      title: AppLocalizations.of(context)!.videos,
                    ),
                    ...videos
                        .take(3)
                        .map((v) => _buildResultItem(context, ref, v)),
                  ],

                  // 4. Artists
                  if (artists.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      title: AppLocalizations.of(context)!.searchArtists,
                      onSeeAll:
                          () =>
                              ref.read(searchFilterProvider.notifier).update(2),
                    ),
                    SizedBox(
                      height: 155,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: artists.length > 8 ? 8 : artists.length,
                        itemBuilder: (context, idx) {
                          final a = artists[idx];
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: ArtistCard(
                              artistId: a.artistId,
                              name: a.name,
                              thumbnailUrl:
                                  a.thumbnails.isNotEmpty
                                      ? a.thumbnails.last.url
                                      : null,
                              monthlyListeners: a.monthlyListeners,
                              cardWidth: 100,
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // 5. Albums
                  if (albums.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      title: AppLocalizations.of(context)!.searchAlbums,
                      onSeeAll:
                          () =>
                              ref.read(searchFilterProvider.notifier).update(3),
                    ),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: albums.length > 8 ? 8 : albums.length,
                        itemBuilder: (context, idx) {
                          final al = albums[idx];
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: AlbumCard(
                              albumId: al.albumId,
                              name: al.name,
                              artist: al.artist.name,
                              thumbnailUrl:
                                  al.thumbnails.isNotEmpty
                                      ? al.thumbnails.last.url
                                      : null,
                              year: al.year,
                              cardWidth: 120,
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // 6. Playlists
                  if (playlists.isNotEmpty) ...[
                    _buildSectionHeader(
                      context,
                      title: AppLocalizations.of(context)!.searchPlaylists,
                      onSeeAll:
                          () =>
                              ref.read(searchFilterProvider.notifier).update(4),
                    ),
                    SizedBox(
                      height: 230,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: playlists.length > 8 ? 8 : playlists.length,
                        itemBuilder: (context, idx) {
                          final pl = playlists[idx];
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: PlaylistCard(
                              playlistId: pl.playlistId,
                              name: pl.name,
                              artist: pl.artist.name,
                              thumbnailUrl:
                                  pl.thumbnails.isNotEmpty
                                      ? pl.thumbnails.last.url
                                      : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultItem(
    BuildContext context,
    WidgetRef ref,
    SearchResult result,
  ) {
    if (result is SongDetailed) {
      return SongTile(
        videoId: result.videoId,
        title: result.name,
        artist: result.artist.name,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        duration: result.duration,
        albumName: result.album?.name,
        albumId: result.album?.albumId,
        artistId: result.artist.artistId,
        playCount: result.playCount,
        isExplicit: result.isExplicit,
      );
    }
    if (result is VideoDetailed) {
      return SongTile(
        videoId: result.videoId,
        title: result.name,
        artist: result.artist.name,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        duration: result.duration,
        isVideo: true,
        playCount: result.viewCount,
        artistId: result.artist.artistId,
        isExplicit: result.isExplicit,
      );
    }
    if (result is ArtistDetailed) {
      return ArtistTile(
        artistId: result.artistId,
        name: result.name,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        monthlyListeners: result.monthlyListeners,
      );
    }
    if (result is AlbumDetailed) {
      return AlbumTile(
        albumId: result.albumId,
        name: result.name,
        artist: result.artist.name,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        year: result.year,
      );
    }
    if (result is PlaylistDetailed) {
      return PlaylistTile(
        playlistId: result.playlistId,
        name: result.name,
        artist: result.artist.name,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
      );
    }
    return const SizedBox.shrink();
  }
}

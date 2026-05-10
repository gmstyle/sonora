import 'dart:async';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/library_repository_provider.dart';
import '../../shared/widgets/album_tile.dart';
import '../../shared/widgets/artist_tile.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/filter_chip_bar.dart';
import '../../shared/widgets/playlist_tile.dart';
import '../../shared/widgets/search_suggestion_tile.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/song_tile.dart';
import 'providers/search_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(searchQueryProvider.notifier).update(query);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (query.isNotEmpty) {
        ref.read(libraryRepositoryProvider).insertSearchEntry(query);
      }
      ref.read(activeSearchQueryProvider.notifier).update(query);
    });
  }

  void _submitSearch(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _debounceTimer?.cancel();
    ref.read(searchQueryProvider.notifier).update(query);
    ref.read(activeSearchQueryProvider.notifier).update(query);
    if (query.isNotEmpty) {
      ref.read(libraryRepositoryProvider).insertSearchEntry(query);
    }
    _focusNode.unfocus();
  }

  void _clearSearch() {
    _searchController.clear();
    _debounceTimer?.cancel();
    ref.read(searchQueryProvider.notifier).update('');
    ref.read(activeSearchQueryProvider.notifier).update('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final activeQuery = ref.watch(activeSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Search songs, artists, albums...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Search for music',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Find your favorite songs, artists, and albums',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Recent Searches',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
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

  const _Suggestions({
    required this.query,
    required this.onTapSuggestion,
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
            return SearchSuggestionTile(
              query: suggestions[index],
              isHistory: false,
              onTap: () => onTapSuggestion(suggestions[index]),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchFilterProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Column(
      children: [
        FilterChipBar(
          options: const ['All', 'Songs', 'Artists', 'Albums', 'Playlists'],
          selectedIndex: filter,
          onSelected: (index) =>
              ref.read(searchFilterProvider.notifier).update(index),
        ),
        Expanded(
          child: resultsAsync.when(
            loading: () => ListView.builder(
              itemCount: 6,
              itemBuilder: (_, _) =>
                  const ShimmerLoading(variant: ShimmerVariant.tile),
            ),
            error: (e, _) => ErrorRetryWidget(
              message: 'Search failed',
              onRetry: () => ref.invalidate(searchResultsProvider),
            ),
            data: (results) {
              if (results.isEmpty) {
                return EmptyStateWidget(
                  icon: Icons.search_off,
                  title: 'No results',
                  body: 'Try a different search term',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: results.length,
                itemBuilder: (context, index) =>
                    _buildResultItem(context, ref, results[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultItem(
      BuildContext context, WidgetRef ref, SearchResult result) {
    if (result is SongDetailed) {
      return SongTile(
        videoId: result.videoId,
        title: result.name,
        artist: result.artist.name,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
        duration: result.duration,
        albumName: result.album?.name,
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
      );
    }
    if (result is ArtistDetailed) {
      return ArtistTile(
        artistId: result.artistId,
        name: result.name,
        thumbnailUrl:
            result.thumbnails.isNotEmpty ? result.thumbnails.last.url : null,
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

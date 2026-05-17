import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/library_repository_provider.dart';
import '../../../providers/music_repository_provider.dart';

class _SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}

class _SearchFilterNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void update(int value) => state = value;
}

/// Notifier for the active (submitted) search query.
/// Persists the query to search history as a side-effect of [submit].
class _ActiveSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;

  Future<void> submit(String query) async {
    state = query;
    if (query.isNotEmpty) {
      await ref.read(libraryNotifierProvider.notifier).insertSearchEntry(query);
    }
  }
}

final searchQueryProvider = NotifierProvider<_SearchQueryNotifier, String>(
  _SearchQueryNotifier.new,
);

final activeSearchQueryProvider =
    NotifierProvider<_ActiveSearchQueryNotifier, String>(
      _ActiveSearchQueryNotifier.new,
    );

final searchFilterProvider = NotifierProvider<_SearchFilterNotifier, int>(
  _SearchFilterNotifier.new,
);

final recentSearchesProvider = FutureProvider((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.getRecentSearches();
});

final searchSuggestionsProvider = FutureProvider<List<String>>((ref) {
  final query = ref.watch(searchQueryProvider);
  if (query.length < 2) return [];
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getSearchSuggestions(query);
});

final searchResultsProvider = FutureProvider<List<SearchResult>>((ref) async {
  final query = ref.watch(activeSearchQueryProvider);
  final filter = ref.watch(searchFilterProvider);
  if (query.isEmpty) return [];
  final repo = ref.watch(musicRepositoryProvider);

  // Use type-specific endpoints when a filter is active: they return richer
  // metadata (e.g. albumId / artistId) than the generic mixed search.
  switch (filter) {
    case 1:
      return repo.searchSongs(query);
    case 2:
      return repo.searchArtists(query);
    case 3:
      return repo.searchAlbums(query);
    case 4:
      return repo.searchPlaylists(query);
    default:
      return repo.search(query);
  }
});

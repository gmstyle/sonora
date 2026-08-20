import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/library_repository_provider.dart';
import '../../../providers/music_repository_provider.dart';

/// Default page size for typed search (uses Innertube continuations).
const kSearchResultLimit = 40;

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

/// Filter indices:
/// 0 All, 1 Songs, 2 Artists, 3 Albums, 4 Playlists,
/// 5 Podcasts, 6 Episodes, 7 Profiles
final searchResultsProvider = FutureProvider<List<SearchResult>>((ref) async {
  final query = ref.watch(activeSearchQueryProvider);
  final filter = ref.watch(searchFilterProvider);
  if (query.isEmpty) return [];
  final repo = ref.watch(musicRepositoryProvider);

  switch (filter) {
    case 1:
      return repo.searchSongs(query, limit: kSearchResultLimit);
    case 2:
      return repo.searchArtists(query, limit: kSearchResultLimit);
    case 3:
      return repo.searchAlbums(query, limit: kSearchResultLimit);
    case 4:
      return repo.searchPlaylists(query, limit: kSearchResultLimit);
    case 5:
      return repo.searchPodcasts(query, limit: kSearchResultLimit);
    case 6:
      return repo.searchEpisodes(query, limit: kSearchResultLimit);
    case 7:
      return repo.searchProfiles(query, limit: kSearchResultLimit);
    default:
      return repo.search(query, limit: kSearchResultLimit);
  }
});

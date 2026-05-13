import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/music_repository_provider.dart';
import '../../../providers/library_repository_provider.dart';

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
      await ref.read(libraryRepositoryProvider).insertSearchEntry(query);
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
  final results = await repo.search(query);
  if (filter == 0) return results;
  return results.where((r) {
    switch (filter) {
      case 1:
        return r is SongDetailed || r is VideoDetailed;
      case 2:
        return r is ArtistDetailed;
      case 3:
        return r is AlbumDetailed;
      case 4:
        return r is PlaylistDetailed;
      default:
        return true;
    }
  }).toList();
});

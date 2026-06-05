import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import '../../repositories/music_repository.dart';
import '../../repositories/library_repository.dart';

class GetDiscoverSuggestionsUseCase {
  final MusicRepository _musicRepository;
  final LibraryRepository _libraryRepository;

  GetDiscoverSuggestionsUseCase(this._musicRepository, this._libraryRepository);

  Future<List<UpNextsDetails>> execute({
    int maxTopTracks = 3,
    int maxResults = 15,
  }) async {
    final history = await _libraryRepository.getRecentHistory(limit: 100);
    if (history.isEmpty) return [];

    final sorted = List.of(history)
      ..sort((a, b) => b.playCount.compareTo(a.playCount));
    final topTracks = sorted.take(maxTopTracks).toList();

    final historyVideoIds = history.map((h) => h.videoId).toSet();

    final results = await Future.wait(
      topTracks.map((t) => _musicRepository.getUpNexts(t.videoId)),
    );

    final allSuggestions = <UpNextsDetails>[];
    final seen = <String>{};

    for (final suggestionList in results) {
      for (final suggestion in suggestionList) {
        if (!historyVideoIds.contains(suggestion.videoId) &&
            seen.add(suggestion.videoId)) {
          allSuggestions.add(suggestion);
          if (allSuggestions.length >= maxResults) break;
        }
      }
      if (allSuggestions.length >= maxResults) break;
    }

    return allSuggestions;
  }
}

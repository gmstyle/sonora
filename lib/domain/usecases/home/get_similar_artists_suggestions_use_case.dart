import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import '../../repositories/music_repository.dart';
import '../../repositories/library_repository.dart';

class GetSimilarArtistsSuggestionsUseCase {
  final MusicRepository _musicRepository;
  final LibraryRepository _libraryRepository;

  GetSimilarArtistsSuggestionsUseCase(
    this._musicRepository,
    this._libraryRepository,
  );

  Future<List<ArtistDetailed>> execute({
    int maxArtists = 3,
    int maxResults = 12,
  }) async {
    final artists = await _libraryRepository.getAllFollowedArtists();
    if (artists.isEmpty) return [];

    final followedIds = artists.map((a) => a.artistId).toSet();
    final toFetch = artists.take(maxArtists).toList();

    final results = await Future.wait(
      toFetch.map((a) => _musicRepository.getArtist(a.artistId)),
    );

    final allSimilar = <ArtistDetailed>[];
    final seen = <String>{};

    for (final artistFull in results) {
      for (final similar in artistFull.similarArtists) {
        if (!followedIds.contains(similar.artistId) &&
            seen.add(similar.artistId)) {
          allSimilar.add(similar);
          if (allSimilar.length >= maxResults) break;
        }
      }
      if (allSimilar.length >= maxResults) break;
    }

    return allSimilar;
  }
}

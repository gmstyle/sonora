import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import '../../repositories/music_repository.dart';
import '../../repositories/library_repository.dart';

class GetNewReleasesUseCase {
  final MusicRepository _musicRepository;
  final LibraryRepository _libraryRepository;

  GetNewReleasesUseCase(this._musicRepository, this._libraryRepository);

  Future<List<AlbumDetailed>> execute({int maxArtists = 10}) async {
    final artists = await _libraryRepository.getAllFollowedArtists();
    if (artists.isEmpty) return [];

    final toFetch = artists.take(maxArtists).toList();

    final results = await Future.wait(
      toFetch.map((a) async {
        final albums = await _musicRepository.getArtistAlbums(a.artistId);
        final singles = await _musicRepository.getArtistSingles(a.artistId);
        return [...albums, ...singles];
      }),
    );

    final currentYear = DateTime.now().year;
    final minYear = currentYear - 2;

    final allAlbums = <AlbumDetailed>[];
    for (final albumList in results) {
      for (final album in albumList) {
        if (album.year != null && album.year! >= minYear) {
          allAlbums.add(album);
        }
      }
    }

    final seen = <String>{};
    final unique = <AlbumDetailed>[];
    for (final album in allAlbums) {
      if (seen.add(album.albumId)) {
        unique.add(album);
      }
    }

    unique.sort((a, b) {
      final yearCompare = (b.year ?? 0).compareTo(a.year ?? 0);
      if (yearCompare != 0) return yearCompare;
      return a.name.compareTo(b.name);
    });
    return unique;
  }
}

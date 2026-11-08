import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/extensions/stat_format.dart';
import 'package:sonora/presentation/features/artist/discography_kind.dart';
import 'package:sonora/presentation/features/artist/featured_preview.dart';
import 'package:sonora/presentation/features/artist/latest_release.dart';

AlbumDetailed _album(String id, {int? year}) {
  return AlbumDetailed(
    type: 'ALBUM',
    albumId: id,
    playlistId: 'pl-$id',
    name: id,
    thumbnails: const [],
    year: year,
  );
}

void main() {
  test('statFigure keeps the leading count', () {
    expect(statFigure('7.28M subscribers'), '7.28M');
    expect(statFigure('46.6M monthly listeners'), '46.6M');
    expect(statFigure('5.242.041.018 visualizzazioni totali'), '5.242.041.018');
    expect(statFigure(null), isNull);
    expect(statFigure('&'), isNull);
    expect(statFigure('Emma & Fabri Fibra'), isNull);
  });

  test('latest release is the album with the highest year', () {
    final albums = [
      _album('old', year: 2001),
      _album('undated'),
      _album('new', year: 2021),
      _album('mid', year: 2009),
    ];

    expect(latestReleaseAlbum(albums)?.albumId, 'new');
    expect(latestReleaseAlbum([_album('undated')]), isNull);
  });

  test('discography chip keeps a shelf that exists', () {
    final available = artistDiscographyKinds(
      hasAlbums: true,
      hasSingles: true,
      hasVideos: false,
    );

    expect(
      resolveDiscographyKind(available, ArtistDiscographyKind.singles),
      ArtistDiscographyKind.singles,
    );
    expect(
      resolveDiscographyKind(available, ArtistDiscographyKind.videos),
      ArtistDiscographyKind.albums,
    );
    expect(
      resolveDiscographyKind(const [], ArtistDiscographyKind.albums),
      isNull,
    );
  });

  test('featured side column keeps the first five playlists', () {
    final ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];

    expect(featuredSidePreview(ids), ['a', 'b', 'c', 'd', 'e']);
    expect(featuredSideOverflow(ids), ['f', 'g']);
    expect(featuredSidePreview(['a', 'b']), ['a', 'b']);
    expect(featuredSideOverflow(['a', 'b']), isEmpty);
    expect(featuredSideOverflow(ids.take(5).toList()), isEmpty);
  });
}

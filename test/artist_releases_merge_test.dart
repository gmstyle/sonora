import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/artist/providers/artist_releases_provider.dart';

AlbumDetailed _release(String id, {String name = 'Release', int? year}) {
  return AlbumDetailed(
    type: 'ALBUM',
    albumId: id,
    playlistId: '',
    name: name,
    year: year,
    thumbnails: const [],
  );
}

void main() {
  test('keeps catalog order and appends preview rows that are missing', () {
    final merged = mergeArtistReleases(
      [_release('a', name: 'Catalog A'), _release('b', name: 'Catalog B')],
      [_release('b', name: 'Preview B'), _release('c', name: 'Preview C')],
    );

    expect(merged.map((release) => release.albumId).toList(), ['a', 'b', 'c']);
    expect(merged[1].name, 'Catalog B');
  });

  test('sorts newest year first and untitled years last', () {
    final sorted = sortArtistReleases([
      _release('a', name: 'Alpha', year: 2010),
      _release('b', name: 'bravo', year: 2020),
      _release('c', name: 'Zebra'),
    ], ArtistReleaseSort.year);

    expect(sorted.map((release) => release.albumId).toList(), ['b', 'a', 'c']);
  });

  test('sorts titles without case', () {
    final sorted = sortArtistReleases([
      _release('b', name: 'bravo'),
      _release('a', name: 'Alpha'),
    ], ArtistReleaseSort.title);

    expect(sorted.map((release) => release.name).toList(), ['Alpha', 'bravo']);
  });

  test('uses the artist-page preview when the catalog is empty', () {
    final merged = mergeArtistReleases(const [], [
      _release('a'),
      _release('a'),
      _release(''),
    ]);

    expect(merged.map((release) => release.albumId).toList(), ['a']);
  });
}

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/artist/providers/artist_releases_provider.dart';

AlbumDetailed _release(String id, {String name = 'Release'}) {
  return AlbumDetailed(
    type: 'ALBUM',
    albumId: id,
    playlistId: '',
    name: name,
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

  test('uses the artist-page preview when the catalog is empty', () {
    final merged = mergeArtistReleases(const [], [
      _release('a'),
      _release('a'),
      _release(''),
    ]);

    expect(merged.map((release) => release.albumId).toList(), ['a']);
  });
}

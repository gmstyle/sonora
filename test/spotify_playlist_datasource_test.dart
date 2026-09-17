import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/datasources/remote/spotify_playlist_datasource.dart';

void main() {
  String embedHtml({
    required String id,
    required String name,
    required List<Map<String, Object?>> tracks,
  }) {
    final trackJson = tracks
        .map((track) {
          final title = track['title'];
          final subtitle = track['subtitle'] ?? '';
          final duration = track['duration'] ?? 1000;
          final entityType = track['entityType'] ?? 'track';
          final explicit = track['isExplicit'] ?? false;
          return '{"title":"$title","subtitle":"$subtitle","duration":$duration,'
              '"entityType":"$entityType","isExplicit":$explicit,'
              '"uri":"spotify:track:abc"}';
        })
        .join(',');
    return '''
<!DOCTYPE html><html><body>
<script id="__NEXT_DATA__" type="application/json">
{"props":{"pageProps":{"state":{"data":{"entity":{
  "type":"playlist","id":"$id","name":"$name","title":"$name",
  "trackList":[$trackJson]
}}}}}}
</script>
</body></html>
''';
  }

  test('parses playlist name and tracks from __NEXT_DATA__', () {
    final snapshot = SpotifyPlaylistDatasource.parseEmbedHtml(
      embedHtml(
        id: '5PlaEJOgemuwJGdHmCTAxg',
        name: 'myLib',
        tracks: [
          {
            'title': 'Someone You Loved',
            'subtitle': 'Lewis Capaldi',
            'duration': 182160,
          },
          {
            'title': 'How to Save a Life',
            'subtitle': 'The Fray',
            'duration': 262533,
            'isExplicit': false,
          },
        ],
      ),
    );

    expect(snapshot.id, '5PlaEJOgemuwJGdHmCTAxg');
    expect(snapshot.name, 'myLib');
    expect(snapshot.tracks, hasLength(2));
    expect(snapshot.tracks.first.title, 'Someone You Loved');
    expect(snapshot.tracks.first.primaryArtist, 'Lewis Capaldi');
    expect(snapshot.tracks.first.durationMs, 182160);
    expect(snapshot.truncated, isFalse);
  });

  test('skips non-track entities such as episodes', () {
    final snapshot = SpotifyPlaylistDatasource.parseEmbedHtml(
      embedHtml(
        id: 'abc123abc123abc123abc1',
        name: 'mixed',
        tracks: [
          {'title': 'A song', 'subtitle': 'Artist'},
          {'title': 'An episode', 'subtitle': 'Show', 'entityType': 'episode'},
        ],
      ),
    );
    expect(snapshot.tracks.map((t) => t.title), ['A song']);
  });

  test('marks snapshots at the embed cap as truncated', () {
    final tracks = [
      for (var i = 0; i < 100; i++) {'title': 'Track $i', 'subtitle': 'A'},
    ];
    final snapshot = SpotifyPlaylistDatasource.parseEmbedHtml(
      embedHtml(id: 'capcapcapcapcapcapcapi', name: 'long', tracks: tracks),
    );
    expect(snapshot.tracks, hasLength(100));
    expect(snapshot.truncated, isTrue);
  });

  test('throws when __NEXT_DATA__ is missing', () {
    expect(
      () => SpotifyPlaylistDatasource.parseEmbedHtml('<html></html>'),
      throwsA(isA<Exception>()),
    );
  });
}

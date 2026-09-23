import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/utils/playable_tracks.dart';

SongDetailed _song(String id, {bool isPlayable = true, String name = ''}) =>
    SongDetailed(
      type: 'SONG',
      videoId: id,
      name: name.isEmpty ? id : name,
      artists: [ArtistBasic(name: 'A')],
      thumbnails: const [],
      isPlayable: isPlayable,
      duration: 60,
    );

void main() {
  test('playableSongs drops greyed-out rows', () {
    final songs = [
      _song('a', isPlayable: false),
      _song('b'),
      _song('c', isPlayable: false),
      _song('d'),
    ];
    expect(playableSongs(songs).map((s) => s.videoId), ['b', 'd']);
    expect(unplayableSongCount(songs), 2);
    expect(playableDuration(songs), const Duration(seconds: 120));
  });

  test('playableLeadIndex maps tapped playable and skips unavailable', () {
    final songs = [
      _song('a', isPlayable: false),
      _song('b'),
      _song('c', isPlayable: false),
      _song('d'),
    ];
    final playable = playableSongs(songs);
    expect(playableLeadIndex(songs, 1, playable: playable), 0); // b
    expect(playableLeadIndex(songs, 0, playable: playable), 0); // next after a → b
    expect(playableLeadIndex(songs, 3, playable: playable), 1); // d
    expect(playableLeadIndex(songs, 2, playable: playable), 1); // next after c → d
  });
}

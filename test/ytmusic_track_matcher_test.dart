import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/playlist_import.dart';
import 'package:sonora/domain/usecases/playlist/ytmusic_track_matcher.dart';

void main() {
  const matcher = YtMusicTrackMatcher();

  SpotifyPlaylistTrack spotify({
    required String title,
    required String subtitle,
    int? durationMs,
  }) => SpotifyPlaylistTrack(
    title: title,
    subtitle: subtitle,
    durationMs: durationMs,
  );

  ImportedTrackCandidate hit({
    required String id,
    required String title,
    required String artist,
    int? durationSec,
  }) => ImportedTrackCandidate(
    videoId: id,
    title: title,
    artist: artist,
    durationSec: durationSec,
  );

  test('picks the candidate with matching artist over a same-title trap', () {
    final track = spotify(
      title: "It's My Life",
      subtitle: 'Bon Jovi',
      durationMs: 224000,
    );
    final chosen = matcher.pickBest(
      track: track,
      candidates: [
        hit(
          id: 'talk',
          title: "It's My Life",
          artist: 'Talk Talk',
          durationSec: 232,
        ),
        hit(
          id: 'bonjovi',
          title: "It's My Life",
          artist: 'Bon Jovi',
          durationSec: 224,
        ),
      ],
    );
    expect(chosen?.videoId, 'bonjovi');
  });

  test(
    'rejects a title-only match when the artist is completely different',
    () {
      final track = spotify(
        title: 'Angel',
        subtitle: 'Shaggy, Rayvon',
        durationMs: 235000,
      );
      final chosen = matcher.pickBest(
        track: track,
        candidates: [
          hit(
            id: 'sarah',
            title: 'Angel',
            artist: 'Sarah McLachlan',
            durationSec: 261,
          ),
        ],
      );
      expect(chosen, isNull);
    },
  );

  test('matches remastered titles to the original recording', () {
    final track = spotify(
      title: 'With Or Without You - Remastered 2007',
      subtitle: 'U2',
      durationMs: 295000,
    );
    final chosen = matcher.pickBest(
      track: track,
      candidates: [
        hit(
          id: 'u2',
          title: 'With or Without You',
          artist: 'U2',
          durationSec: 296,
        ),
      ],
    );
    expect(chosen?.videoId, 'u2');
  });

  test('splits Spotify subtitle artists on comma and nbsp', () {
    final track = spotify(
      title: "It Wasn't Me",
      subtitle: 'Shaggy,\u00a0Rik Rok',
      durationMs: 227600,
    );
    expect(track.artistNames, ['Shaggy', 'Rik Rok']);
    final chosen = matcher.pickBest(
      track: track,
      candidates: [
        hit(
          id: 'shaggy',
          title: "It Wasn't Me",
          artist: 'Shaggy',
          durationSec: 227,
        ),
      ],
    );
    expect(chosen?.videoId, 'shaggy');
  });

  test('builds title+artist search queries and a stripped fallback', () {
    final track = spotify(
      title: 'Just Give Me a Reason (feat. Nate Ruess)',
      subtitle: 'P!nk, Nate Ruess',
    );
    expect(
      matcher.searchQueries(track),
      containsAllInOrder([
        'Just Give Me a Reason (feat. Nate Ruess) P!nk',
        'Just Give Me a Reason P!nk',
      ]),
    );
  });
}

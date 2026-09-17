import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/utils/playlist_url_parser.dart';
import 'package:sonora/domain/models/playlist_import.dart';

void main() {
  group('PlaylistUrlParser', () {
    test('parses YouTube Music playlist URLs', () {
      expect(
        PlaylistUrlParser.parse(
          'https://music.youtube.com/playlist?list=PLabcdefghijk',
        ),
        const RemotePlaylistRef(
          kind: PlaylistImportKind.youtube,
          id: 'PLabcdefghijk',
        ),
      );
    });

    test('parses YouTube watch URLs with list=', () {
      expect(
        PlaylistUrlParser.parse(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=RDabcdefghijk',
        )?.id,
        'RDabcdefghijk',
      );
    });

    test('parses a raw YouTube playlist id', () {
      expect(
        PlaylistUrlParser.parse('PLabcdefghijklmnop'),
        const RemotePlaylistRef(
          kind: PlaylistImportKind.youtube,
          id: 'PLabcdefghijklmnop',
        ),
      );
    });

    test('parses Spotify open URLs including si query and intl locale', () {
      expect(
        PlaylistUrlParser.parse(
          'https://open.spotify.com/playlist/5PlaEJOgemuwJGdHmCTAxg?si=240a7072fc3e4e58',
        ),
        const RemotePlaylistRef(
          kind: PlaylistImportKind.spotify,
          id: '5PlaEJOgemuwJGdHmCTAxg',
        ),
      );
      expect(
        PlaylistUrlParser.parse(
          'https://open.spotify.com/intl-it/playlist/5PlaEJOgemuwJGdHmCTAxg',
        )?.id,
        '5PlaEJOgemuwJGdHmCTAxg',
      );
    });

    test('parses Spotify embed URLs and spotify: URIs', () {
      expect(
        PlaylistUrlParser.parse(
          'https://open.spotify.com/embed/playlist/5PlaEJOgemuwJGdHmCTAxg',
        )?.id,
        '5PlaEJOgemuwJGdHmCTAxg',
      );
      expect(
        PlaylistUrlParser.parse('spotify:playlist:5PlaEJOgemuwJGdHmCTAxg')?.id,
        '5PlaEJOgemuwJGdHmCTAxg',
      );
    });

    test(
      'prefers Spotify when the host is Spotify even if list= is present',
      () {
        expect(
          PlaylistUrlParser.parse(
            'https://open.spotify.com/playlist/5PlaEJOgemuwJGdHmCTAxg?list=foo',
          )?.kind,
          PlaylistImportKind.spotify,
        );
      },
    );

    test('returns null for empty or unrelated input', () {
      expect(PlaylistUrlParser.parse(''), isNull);
      expect(PlaylistUrlParser.parse('not a playlist'), isNull);
      expect(
        PlaylistUrlParser.parse('https://example.com/playlist/abc'),
        isNull,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/link/sonora_link.dart';

void main() {
  group('buildSonoraLink / parseSonoraLink', () {
    test('round-trips every link kind', () {
      final cases = <SonoraLink>[
        const SonoraLink(kind: SonoraLinkKind.track, id: 'dQw4w9WgXcQ'),
        const SonoraLink(kind: SonoraLinkKind.episode, id: 'abcdefghijk'),
        const SonoraLink(kind: SonoraLinkKind.artist, id: 'UCxxxxxxxx'),
        const SonoraLink(kind: SonoraLinkKind.album, id: 'MPREb_abc'),
        const SonoraLink(kind: SonoraLinkKind.playlist, id: 'VLxxxxxx'),
        const SonoraLink(kind: SonoraLinkKind.podcast, id: 'MPSPxxxxxx'),
        const SonoraLink(kind: SonoraLinkKind.user, id: 'UCyyyyyyyy'),
        const SonoraLink(
          kind: SonoraLinkKind.browseSection,
          id: 'FEmusic_moods',
          params: 'ggMPOgIIARAB',
          title: 'Moods & moments',
        ),
      ];

      for (final original in cases) {
        final built = buildSonoraLink(original);
        expect(built, startsWith('sonora://'));
        final parsed = parseSonoraLink(built);
        expect(parsed, original, reason: 'failed for $original → $built');
      }
    });

    test('encodes special characters in path and query', () {
      final link = const SonoraLink(
        kind: SonoraLinkKind.browseSection,
        id: 'id with spaces',
        title: 'A & B',
        params: 'p=1&q=2',
      );
      final built = buildSonoraLink(link);
      expect(built, contains('browse-section'));
      expect(built, isNot(contains(' ')));
      final parsed = parseSonoraLink(built);
      expect(parsed?.id, 'id with spaces');
      expect(parsed?.title, 'A & B');
      expect(parsed?.params, 'p=1&q=2');
    });

    test('trims whitespace and newlines', () {
      expect(
        parseSonoraLink('  sonora:///track/dQw4w9WgXcQ\n'),
        const SonoraLink(kind: SonoraLinkKind.track, id: 'dQw4w9WgXcQ'),
      );
    });

    test('accepts single-slash sonora:/ form', () {
      expect(
        parseSonoraLink('sonora:/album/MPREb_abc'),
        const SonoraLink(kind: SonoraLinkKind.album, id: 'MPREb_abc'),
      );
    });

    test('rejects other schemes and malformed paths', () {
      expect(parseSonoraLink('https://music.youtube.com/watch?v=x'), isNull);
      expect(parseSonoraLink('sonora://'), isNull);
      expect(parseSonoraLink('sonora:///unknown/id'), isNull);
      expect(parseSonoraLink('sonora:///track/'), isNull);
      expect(parseSonoraLink(''), isNull);
      expect(parseSonoraLink('   '), isNull);
    });

    test('location matches GoRouter paths', () {
      expect(
        const SonoraLink(kind: SonoraLinkKind.artist, id: 'UC1').location,
        '/artist/UC1',
      );
      expect(
        const SonoraLink(kind: SonoraLinkKind.track, id: 'abc').location,
        '/track/abc',
      );
      final browse = const SonoraLink(
        kind: SonoraLinkKind.browseSection,
        id: 'FE',
        params: 'p',
        title: 'T',
      );
      expect(browse.location, contains('/browse-section/FE'));
      expect(browse.location, contains('params=p'));
      expect(browse.location, contains('title=T'));
    });
  });

  group('formatSonoraShareText', () {
    const track = SonoraLink(kind: SonoraLinkKind.track, id: 'dQw4w9WgXcQ');

    test('title and subtitle become a caption line above the URL', () {
      final text = formatSonoraShareText(
        track,
        title: 'Song',
        subtitle: 'Artist',
      );
      expect(text, 'Song — Artist\n${buildSonoraLink(track)}');
    });

    test('title only omits the em dash', () {
      expect(
        formatSonoraShareText(track, title: 'Song'),
        'Song\n${buildSonoraLink(track)}',
      );
    });

    test('no title yields URL only', () {
      expect(formatSonoraShareText(track), buildSonoraLink(track));
      expect(buildSonoraShareCaption(title: null, subtitle: 'X'), isNull);
      expect(buildSonoraShareCaption(title: '  ', subtitle: 'X'), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/link/sonora_link.dart';
import 'package:sonora/core/link/sonora_link_handler.dart';

void main() {
  group('dispatchSonoraLink', () {
    test('plays track ids without navigating', () async {
      String? played;
      String? navigated;

      await dispatchSonoraLink(
        const SonoraLink(kind: SonoraLinkKind.track, id: 'vid12345678'),
        playTrack: (id) async => played = id,
        navigate: (loc) => navigated = loc,
      );

      expect(played, 'vid12345678');
      expect(navigated, isNull);
    });

    test('navigates non-track kinds', () async {
      final navigated = <String>[];
      var playCalls = 0;

      for (final link in [
        const SonoraLink(kind: SonoraLinkKind.episode, id: 'ep1'),
        const SonoraLink(kind: SonoraLinkKind.artist, id: 'UC1'),
        const SonoraLink(kind: SonoraLinkKind.album, id: 'alb1'),
        const SonoraLink(kind: SonoraLinkKind.playlist, id: 'pl1'),
        const SonoraLink(kind: SonoraLinkKind.podcast, id: 'pod1'),
        const SonoraLink(kind: SonoraLinkKind.user, id: 'user1'),
        const SonoraLink(
          kind: SonoraLinkKind.browseSection,
          id: 'FE',
          params: 'p',
          title: 'T',
        ),
      ]) {
        await dispatchSonoraLink(
          link,
          playTrack: (_) async => playCalls++,
          navigate: navigated.add,
        );
      }

      expect(playCalls, 0);
      expect(navigated, [
        '/episode/ep1',
        '/artist/UC1',
        '/album/alb1',
        '/playlist/pl1',
        '/podcast/pod1',
        '/user/user1',
        '/browse-section/FE?params=p&title=T',
      ]);
    });
  });
}

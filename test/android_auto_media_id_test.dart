import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/player/android_auto/aa_media_id.dart';

void main() {
  group('AaMediaId.playTrack codec', () {
    test('round-trips contextual playback target with colons in id', () {
      final id = AaMediaId.playTrack(
        contextKind: AaMediaId.ctxDownloadGroup,
        contextId: 'album:MPREb_abc?x=1&y=2',
        index: 4,
        videoId: 'dQw4w9WgXcQ',
      );

      final parsed = AaMediaId.tryParsePlayTrack(id);
      expect(parsed, isNotNull);
      expect(parsed!.contextKind, AaMediaId.ctxDownloadGroup);
      expect(parsed.contextId, 'album:MPREb_abc?x=1&y=2');
      expect(parsed.index, 4);
      expect(parsed.videoId, 'dQw4w9WgXcQ');
    });

    test('rejects invalid or negative index play targets', () {
      expect(AaMediaId.tryParsePlayTrack('plainVideoId'), isNull);
      expect(
        AaMediaId.tryParsePlayTrack('__play__?ctx=album&id=a&i=-1&v=vid'),
        isNull,
      );
      expect(
        AaMediaId.tryParsePlayTrack('__play__?ctx=album&id=a&i=0&v='),
        isNull,
      );
      expect(
        AaMediaId.tryParsePlayTrack('__play__?ctx=&id=a&i=0&v=vid'),
        isNull,
      );
    });
  });

  group('AaMediaId.action codec', () {
    test('round-trips action with URL-encoded target id', () {
      final id = AaMediaId.action(
        AaMediaId.actAffinity,
        AaMediaId.ctxPodcast,
        'MPSP:special/id?foo=bar',
      );

      final parsed = AaMediaId.tryParseAction(id);
      expect(parsed, isNotNull);
      expect(parsed!.action, AaMediaId.actAffinity);
      expect(parsed.targetKind, AaMediaId.ctxPodcast);
      expect(parsed.targetId, 'MPSP:special/id?foo=bar');
    });

    test('returns null on malformed action IDs', () {
      expect(AaMediaId.tryParseAction('__action__:onlyone'), isNull);
      expect(AaMediaId.tryParseAction('__action__:a:b'), isNull);
      expect(AaMediaId.tryParseAction('__action__::kind:id'), isNull);
      expect(AaMediaId.tryParseAction('__action__:act::id'), isNull);
      expect(AaMediaId.tryParseAction('not_an_action'), isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/utils/url_staleness.dart';

void main() {
  group('UrlStaleness', () {
    test('returns true for null or empty url', () {
      expect(UrlStaleness.isStale(null), isTrue);
      expect(UrlStaleness.isStale(''), isTrue);
    });

    test('returns false for non-expired HTTP url when not idle', () {
      final futureExpire =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final url = 'https://googlevideo.com/videoplayback?expire=$futureExpire';
      expect(UrlStaleness.isStale(url), isFalse);
    });

    test('returns true for expired HTTP url', () {
      final pastExpire = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 3600;
      final url = 'https://googlevideo.com/videoplayback?expire=$pastExpire';
      expect(UrlStaleness.isStale(url), isTrue);
    });

    test('returns true when lastPauseTimestamp exceeds maxIdleDuration', () {
      final futureExpire =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final url = 'https://googlevideo.com/videoplayback?expire=$futureExpire';
      final oldPause = DateTime.now().subtract(const Duration(minutes: 20));

      expect(UrlStaleness.isStale(url, lastPauseTimestamp: oldPause), isTrue);
    });

    test('returns false when lastPauseTimestamp is recent', () {
      final futureExpire =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
      final url = 'https://googlevideo.com/videoplayback?expire=$futureExpire';
      final recentPause = DateTime.now().subtract(const Duration(minutes: 5));

      expect(
        UrlStaleness.isStale(url, lastPauseTimestamp: recentPause),
        isFalse,
      );
    });
  });
}

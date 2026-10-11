import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/utils/linux_single_instance.dart';

void main() {
  group('extractSonoraUriFromArgs', () {
    test('returns the first sonora URI', () {
      expect(
        extractSonoraUriFromArgs([
          '--some-flag',
          'sonora:///track/dQw4w9WgXcQ',
          'sonora:///album/x',
        ]),
        'sonora:///track/dQw4w9WgXcQ',
      );
    });

    test('ignores non-sonora args', () {
      expect(
        extractSonoraUriFromArgs(['--flag', 'https://example.com', 'plain']),
        isNull,
      );
      expect(extractSonoraUriFromArgs([]), isNull);
    });

    test('trims whitespace around the URI', () {
      expect(
        extractSonoraUriFromArgs(['  sonora:///artist/UC1  ']),
        'sonora:///artist/UC1',
      );
    });
  });
}

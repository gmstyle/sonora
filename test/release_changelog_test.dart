import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/usecases/update/release_changelog.dart';

void main() {
  group('sanitizeReleaseNotes', () {
    test('returns notes unchanged when there is no boilerplate', () {
      const body = '''
### Features

- **home**: Refresh UI
''';
      expect(
        sanitizeReleaseNotes(body),
        '### Features\n\n- **home**: Refresh UI',
      );
    });

    test('strips version header, rules, and Downloads footer', () {
      const body = '''
**Version:** 1.7.1
**Build:** 57

---

### Features

- **home**: Refresh UI

---

## Downloads
- **Android APK**: see attached artifacts
''';
      expect(
        sanitizeReleaseNotes(body),
        '### Features\n\n- **home**: Refresh UI',
      );
    });

    test('strips GitHub auto-generated full changelog line', () {
      const body = '''
## What's Changed
* fix(player): restore video by @gmstyle in https://example.com/1

**Full Changelog**: https://github.com/gmstyle/sonora/compare/v1.6.7+54...v1.7.0+56
''';
      final sanitized = sanitizeReleaseNotes(body);
      expect(sanitized, contains("What's Changed"));
      expect(sanitized, isNot(contains('Full Changelog')));
    });
  });

  group('parseReleaseNotes', () {
    test('parses section titles and bullet items', () {
      const body = '''
### Features

- **home**: Refresh UI
- **ytmusic**: Wire search APIs

### Bug Fixes

- **player**: Restore video playback
''';
      final sections = parseReleaseNotes(body);
      expect(sections, hasLength(2));
      expect(sections[0].title, 'Features');
      expect(sections[0].items, [
        'home: Refresh UI',
        'ytmusic: Wire search APIs',
      ]);
      expect(sections[1].title, 'Bug Fixes');
      expect(sections[1].items, ['player: Restore video playback']);
    });

    test('returns empty list for blank notes', () {
      expect(parseReleaseNotes('   \n'), isEmpty);
    });
  });
}

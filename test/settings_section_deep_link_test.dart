import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/settings/settings_shared.dart';

void main() {
  group('settingsCategoryFromSection', () {
    test('maps ask to SettingsCategory.ai', () {
      expect(
        settingsCategoryFromSection(kSettingsAskSection),
        SettingsCategory.ai,
      );
    });

    test('returns null for unknown or empty section', () {
      expect(settingsCategoryFromSection(null), isNull);
      expect(settingsCategoryFromSection(''), isNull);
      expect(settingsCategoryFromSection('playback'), isNull);
    });

    test('kSettingsAskPath includes section query', () {
      expect(kSettingsAskPath, '/settings?section=ask');
    });
  });
}

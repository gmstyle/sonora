import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/settings/settings_shared.dart';

void main() {
  group('settingsCategoryFromSection', () {
    test('maps ask to SettingsCategory.ai', () {
      expect(
        settingsCategoryFromSection(kSettingsAskSection),
        SettingsCategory.ai,
      );
      expect(settingsCategoryFromSection('ai'), SettingsCategory.ai);
    });

    test('maps every category slug to its category', () {
      for (final category in SettingsCategory.values) {
        expect(
          settingsCategoryFromSection(category.sectionSlug),
          category,
          reason: category.sectionSlug,
        );
      }
    });

    test('slugs are unique', () {
      final slugs = SettingsCategory.values
          .map((category) => category.sectionSlug)
          .toSet();
      expect(slugs, hasLength(SettingsCategory.values.length));
    });

    test('returns null for unknown or empty section', () {
      expect(settingsCategoryFromSection(null), isNull);
      expect(settingsCategoryFromSection(''), isNull);
      expect(settingsCategoryFromSection('unknown'), isNull);
    });

    test('kSettingsAskPath includes section query', () {
      expect(kSettingsAskPath, '/settings?section=ask');
    });
  });

  group('SettingsCategoryGroup', () {
    test('covers every category exactly once', () {
      final grouped = SettingsCategoryGroup.values
          .expand((group) => group.categories)
          .toList();
      expect(grouped.toSet(), SettingsCategory.values.toSet());
      expect(grouped, hasLength(SettingsCategory.values.length));
    });
  });
}

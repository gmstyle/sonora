import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/settings/settings_shared.dart';

void main() {
  group('visibleSettingsCategories', () {
    test('hides background on non-Android', () {
      final cats = visibleSettingsCategories(
        isAndroid: false,
        isAndroidTv: false,
      );
      expect(cats, isNot(contains(SettingsCategory.background)));
      expect(cats, contains(SettingsCategory.appearance));
      expect(cats, contains(SettingsCategory.about));
    });

    test('shows background on Android phone', () {
      final cats = visibleSettingsCategories(
        isAndroid: true,
        isAndroidTv: false,
      );
      expect(cats, contains(SettingsCategory.background));
    });

    test('hides background on Android TV', () {
      final cats = visibleSettingsCategories(
        isAndroid: true,
        isAndroidTv: true,
      );
      expect(cats, isNot(contains(SettingsCategory.background)));
      expect(cats, contains(SettingsCategory.playback));
      expect(cats, contains(SettingsCategory.backup));
    });
  });
}

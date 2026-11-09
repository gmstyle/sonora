import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/settings/providers/settings_category_provider.dart';
import 'package:sonora/presentation/features/settings/settings_shared.dart';

void main() {
  group('SettingsCategoryNotifier', () {
    test('starts on appearance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(settingsCategoryProvider),
        SettingsCategory.appearance,
      );
    });

    test('select replaces the current category', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(settingsCategoryProvider.notifier)
          .select(SettingsCategory.privacy);

      expect(
        container.read(settingsCategoryProvider),
        SettingsCategory.privacy,
      );
    });

    test('select on the current category does not notify', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var notifications = 0;
      container.listen(settingsCategoryProvider, (_, _) => notifications++);

      final notifier = container.read(settingsCategoryProvider.notifier);
      notifier.select(SettingsCategory.playback);
      notifier.select(SettingsCategory.playback);

      expect(notifications, 1);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonora/presentation/providers/battery_prompt_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';

void main() {
  group('shouldShowBatteryPrompt', () {
    test('returns false when not Android', () {
      expect(
        shouldShowBatteryPrompt(
          isAndroid: false,
          dismissedForever: false,
          isBatteryOptimizationDisabled: false,
        ),
        isFalse,
      );
    });

    test('returns false when dismissed forever', () {
      expect(
        shouldShowBatteryPrompt(
          isAndroid: true,
          dismissedForever: true,
          isBatteryOptimizationDisabled: false,
        ),
        isFalse,
      );
    });

    test('returns false when battery optimization is already disabled', () {
      expect(
        shouldShowBatteryPrompt(
          isAndroid: true,
          dismissedForever: false,
          isBatteryOptimizationDisabled: true,
        ),
        isFalse,
      );
    });

    test('returns false when plugin status is unknown (null)', () {
      expect(
        shouldShowBatteryPrompt(
          isAndroid: true,
          dismissedForever: false,
          isBatteryOptimizationDisabled: null,
        ),
        isFalse,
      );
    });

    test(
      'returns true when Android, not dismissed, optimization still active',
      () {
        expect(
          shouldShowBatteryPrompt(
            isAndroid: true,
            dismissedForever: false,
            isBatteryOptimizationDisabled: false,
          ),
          isTrue,
        );
      },
    );
  });

  group('dismissBatteryPromptForever', () {
    test('persists kBatteryPromptDismissedKey', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      // Warm up SettingsNotifier so _prefs is initialized.
      container.read(settingsProvider);

      await container
          .read(settingsProvider.notifier)
          .dismissBatteryPromptForever();

      expect(prefs.getBool(kBatteryPromptDismissedKey), isTrue);
    });
  });
}

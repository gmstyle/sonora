import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sonora/presentation/providers/ask_intro_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';

void main() {
  group('shouldShowAiIntro', () {
    test('returns true when not seen', () {
      expect(shouldShowAiIntro(seen: false), isTrue);
    });

    test('returns false when already seen', () {
      expect(shouldShowAiIntro(seen: true), isFalse);
    });
  });

  group('markAiIntroSeen', () {
    test('persists kAiIntroSeenKey', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      container.read(settingsProvider);

      await container.read(settingsProvider.notifier).markAiIntroSeen();

      expect(prefs.getBool(kAiIntroSeenKey), isTrue);
      container.invalidate(shouldShowAiIntroProvider);
      expect(await container.read(shouldShowAiIntroProvider.future), isFalse);
    });
  });
}

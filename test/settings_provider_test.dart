import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';

void main() {
  group('Settings model', () {
    test('default values are correct', () {
      const settings = Settings();
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.useDynamicColor, true);
      expect(settings.useAmoled, false);
      expect(settings.gl, 'US');
      expect(settings.hl, 'en');
      expect(settings.crossfadeSeconds, 2);
      expect(settings.restoreQueueOnStartup, true);
      expect(settings.autoPlayUpNext, true);
      expect(settings.downloadPath, isNull);
      expect(settings.downloadOnlyOnWifi, false);
      expect(settings.trackHistory, true);
      expect(settings.checkUpdatesOnStartup, true);
      expect(settings.crossfadeDuration, const Duration(seconds: 2));
    });

    test('custom constructor values', () {
      const settings = Settings(
        themeMode: ThemeMode.dark,
        useDynamicColor: false,
        useAmoled: true,
        gl: 'IT',
        hl: 'it',
        crossfadeSeconds: 5,
        restoreQueueOnStartup: false,
        autoPlayUpNext: false,
        downloadPath: '/music',
        downloadOnlyOnWifi: true,
        trackHistory: false,
        checkUpdatesOnStartup: false,
      );
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.useDynamicColor, false);
      expect(settings.useAmoled, true);
      expect(settings.gl, 'IT');
      expect(settings.hl, 'it');
      expect(settings.crossfadeSeconds, 5);
      expect(settings.restoreQueueOnStartup, false);
      expect(settings.autoPlayUpNext, false);
      expect(settings.downloadPath, '/music');
      expect(settings.downloadOnlyOnWifi, true);
      expect(settings.trackHistory, false);
      expect(settings.checkUpdatesOnStartup, false);
      expect(settings.crossfadeDuration, const Duration(seconds: 5));
    });

    test('copyWith preserves unspecified fields', () {
      const settings = Settings(crossfadeSeconds: 10);
      final updated = settings.copyWith(useAmoled: true);
      expect(updated.crossfadeSeconds, 10);
      expect(updated.useAmoled, true);
      expect(updated.themeMode, ThemeMode.system);
    });

    test('copyWith clearDownloadPath sets path to null', () {
      const settings = Settings(downloadPath: '/music');
      final updated = settings.copyWith(clearDownloadPath: true);
      expect(updated.downloadPath, isNull);
    });

    test('copyWith downloadPath overrides when not cleared', () {
      const settings = Settings(downloadPath: '/old');
      final updated = settings.copyWith(downloadPath: '/new');
      expect(updated.downloadPath, '/new');
    });

    test('crossfadeDuration computed correctly', () {
      const zero = Settings(crossfadeSeconds: 0);
      expect(zero.crossfadeDuration, Duration.zero);

      const fifteen = Settings(crossfadeSeconds: 15);
      expect(fifteen.crossfadeDuration, const Duration(seconds: 15));
    });
  });

  group('SettingsNotifier', () {
    test('initial state reads from SharedPreferences defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final settings = container.read(settingsProvider);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.useDynamicColor, true);
      expect(settings.useAmoled, false);
      expect(settings.gl, 'US');
      expect(settings.hl, 'en');
      expect(settings.crossfadeSeconds, 2);
      expect(settings.restoreQueueOnStartup, true);
      expect(settings.autoPlayUpNext, true);
      expect(settings.downloadPath, isNull);
      expect(settings.downloadOnlyOnWifi, false);
      expect(settings.trackHistory, true);
      expect(settings.checkUpdatesOnStartup, true);
    });

    test('initial state reads persisted values', () async {
      SharedPreferences.setMockInitialValues({
        kThemeModeKey: ThemeMode.dark.index,
        kUseDynamicColorKey: false,
        kUseAmoledKey: true,
        kGlKey: 'IT',
        kHlKey: 'it',
        kCrossfadeSecondsKey: 5,
        kRestoreQueueKey: false,
        kAutoPlayUpNextKey: false,
        kDownloadPathKey: '/music',
        kDownloadWifiKey: true,
        kTrackHistoryKey: false,
        kCheckUpdatesKey: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final settings = container.read(settingsProvider);
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.useDynamicColor, false);
      expect(settings.useAmoled, true);
      expect(settings.gl, 'IT');
      expect(settings.hl, 'it');
      expect(settings.crossfadeSeconds, 5);
      expect(settings.restoreQueueOnStartup, false);
      expect(settings.autoPlayUpNext, false);
      expect(settings.downloadPath, '/music');
      expect(settings.downloadOnlyOnWifi, true);
      expect(settings.trackHistory, false);
      expect(settings.checkUpdatesOnStartup, false);
    });

    test('setThemeMode updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      final settings = container.read(settingsProvider);
      expect(settings.themeMode, ThemeMode.dark);
      expect(prefs.getInt(kThemeModeKey), ThemeMode.dark.index);
    });

    test('setUseDynamicColor updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).setUseDynamicColor(false);
      expect(container.read(settingsProvider).useDynamicColor, false);
      expect(prefs.getBool(kUseDynamicColorKey), false);
    });

    test('setUseAmoled updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).setUseAmoled(true);
      expect(container.read(settingsProvider).useAmoled, true);
      expect(prefs.getBool(kUseAmoledKey), true);
    });

    test('setCrossfadeSeconds updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).setCrossfadeSeconds(7);
      final settings = container.read(settingsProvider);
      expect(settings.crossfadeSeconds, 7);
      expect(settings.crossfadeDuration, const Duration(seconds: 7));
      expect(prefs.getInt(kCrossfadeSecondsKey), 7);
    });

    test('setRestoreQueueOnStartup updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setRestoreQueueOnStartup(false);
      expect(container.read(settingsProvider).restoreQueueOnStartup, false);
      expect(prefs.getBool(kRestoreQueueKey), false);
    });

    test('setAutoPlayUpNext updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).setAutoPlayUpNext(false);
      expect(container.read(settingsProvider).autoPlayUpNext, false);
      expect(prefs.getBool(kAutoPlayUpNextKey), false);
    });

    test('setDownloadPath updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setDownloadPath('/downloads');
      expect(container.read(settingsProvider).downloadPath, '/downloads');
      expect(prefs.getString(kDownloadPathKey), '/downloads');
    });

    test('setDownloadPath null clears persisted path', () async {
      SharedPreferences.setMockInitialValues({kDownloadPathKey: '/old'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).setDownloadPath(null);
      expect(container.read(settingsProvider).downloadPath, isNull);
      expect(prefs.containsKey(kDownloadPathKey), false);
    });

    test('setDownloadOnlyOnWifi updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setDownloadOnlyOnWifi(true);
      expect(container.read(settingsProvider).downloadOnlyOnWifi, true);
      expect(prefs.getBool(kDownloadWifiKey), true);
    });

    test('setTrackHistory updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).setTrackHistory(false);
      expect(container.read(settingsProvider).trackHistory, false);
      expect(prefs.getBool(kTrackHistoryKey), false);
    });

    test('setCheckUpdatesOnStartup updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setCheckUpdatesOnStartup(false);
      expect(container.read(settingsProvider).checkUpdatesOnStartup, false);
      expect(prefs.getBool(kCheckUpdatesKey), false);
    });

    test('multiple setters compose correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(settingsProvider.notifier);
      await notifier.setUseAmoled(true);
      await notifier.setRestoreQueueOnStartup(false);
      await notifier.setCrossfadeSeconds(10);
      await notifier.setTrackHistory(false);

      final settings = container.read(settingsProvider);
      expect(settings.useAmoled, true);
      expect(settings.restoreQueueOnStartup, false);
      expect(settings.crossfadeSeconds, 10);
      expect(settings.trackHistory, false);
      expect(settings.themeMode, ThemeMode.system);
    });
  });
}

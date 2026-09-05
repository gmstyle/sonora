import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/domain/models/media_cache_size.dart';
import 'package:sonora/domain/models/media_quality.dart';
import 'package:sonora/presentation/providers/equalizer_provider.dart';
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
      expect(settings.streamAudioQuality, MediaQuality.high);
      expect(settings.downloadQuality, MediaQuality.high);
      expect(settings.downloadPath, isNull);
      expect(settings.downloadOnlyOnWifi, false);
      expect(settings.trackHistory, true);
      expect(settings.checkUpdatesOnStartup, true);
      expect(settings.crossfadeDuration, const Duration(seconds: 2));
      expect(settings.mediaCacheSize, MediaCacheSize.gb1);
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
      expect(settings.streamAudioQuality, MediaQuality.high);
      expect(settings.mediaCacheSize, MediaCacheSize.gb1);
      expect(settings.downloadQuality, MediaQuality.high);
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
        kStreamAudioQualityKey: 'mid',
        kMediaCacheSizeKey: 'gb5',
        kDownloadQualityKey: 'low',
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
      expect(settings.streamAudioQuality, MediaQuality.mid);
      expect(settings.mediaCacheSize, MediaCacheSize.gb5);
      expect(settings.downloadQuality, MediaQuality.low);
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

    test(
      'upgrade reads leftover streamQuality then persists new key',
      () async {
        SharedPreferences.setMockInitialValues({
          kLegacyStreamQualityKey: 'low',
          kLegacyEnableVideoPlaybackKey: true,
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        final settings = container.read(settingsProvider);
        expect(settings.streamAudioQuality, MediaQuality.low);

        await migrateLegacySettingsPrefs(prefs);
        expect(prefs.getString(kStreamAudioQualityKey), 'low');
        expect(prefs.containsKey(kLegacyStreamQualityKey), false);
        expect(prefs.containsKey(kLegacyEnableVideoPlaybackKey), false);
      },
    );

    test(
      'upgrade prefers streamAudioQuality over leftover streamQuality',
      () async {
        SharedPreferences.setMockInitialValues({
          kLegacyStreamQualityKey: 'low',
          kStreamAudioQualityKey: 'high',
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        final settings = container.read(settingsProvider);
        expect(settings.streamAudioQuality, MediaQuality.high);
      },
    );

    test('setStreamAudioQuality updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setStreamAudioQuality(MediaQuality.low);
      expect(
        container.read(settingsProvider).streamAudioQuality,
        MediaQuality.low,
      );
      expect(prefs.getString(kStreamAudioQualityKey), 'low');
    });

    test('setMediaCacheSize updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setMediaCacheSize(MediaCacheSize.mb500);
      expect(
        container.read(settingsProvider).mediaCacheSize,
        MediaCacheSize.mb500,
      );
      expect(prefs.getString(kMediaCacheSizeKey), 'mb500');
    });

    test('setDownloadQuality updates state and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container
          .read(settingsProvider.notifier)
          .setDownloadQuality(MediaQuality.mid);
      expect(
        container.read(settingsProvider).downloadQuality,
        MediaQuality.mid,
      );
      expect(prefs.getString(kDownloadQualityKey), 'mid');
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

  group('Settings backup map', () {
    test('toBackupMap uses k*Key constants and excludes local leftovers', () {
      const settings = Settings(
        themeMode: ThemeMode.dark,
        useDynamicColor: false,
        useAmoled: true,
        gl: 'IT',
        hl: 'it',
        crossfadeSeconds: 8,
        restoreQueueOnStartup: false,
        autoPlayUpNext: false,
        streamAudioQuality: MediaQuality.mid,
        mediaCacheSize: MediaCacheSize.gb2,
        downloadQuality: MediaQuality.low,
        downloadPath: '/device/music',
        downloadOnlyOnWifi: true,
        trackHistory: false,
        checkUpdatesOnStartup: false,
        isLibraryGridView: true,
        reduceEffects: true,
        offlineMode: true,
        useVinylStyle: false,
        localSyncEnabled: true,
        localSyncAutoEnabled: true,
        playlistConflictStrategy: 'overwrite',
      );

      final map = settings.toBackupMap();
      expect(map.keys.toSet(), kSettingsBackupKeys);
      expect(map[kThemeModeKey], ThemeMode.dark.index);
      expect(map[kUseDynamicColorKey], false);
      expect(map[kUseAmoledKey], true);
      expect(map[kGlKey], 'IT');
      expect(map[kHlKey], 'it');
      expect(map[kCrossfadeSecondsKey], 8);
      expect(map[kRestoreQueueKey], false);
      expect(map[kAutoPlayUpNextKey], false);
      expect(map[kStreamAudioQualityKey], 'mid');
      expect(map[kMediaCacheSizeKey], 'gb2');
      expect(map[kDownloadQualityKey], 'low');
      expect(map[kDownloadWifiKey], true);
      expect(map[kTrackHistoryKey], false);
      expect(map[kCheckUpdatesKey], false);
      expect(map[kIsLibraryGridViewKey], true);
      expect(map[kReduceEffectsKey], true);
      expect(map[kOfflineModeKey], true);
      expect(map[kUseVinylStyleKey], false);
      expect(map[kLocalSyncEnabledKey], true);
      expect(map[kLocalSyncAutoEnabledKey], true);
      expect(map[kPlaylistConflictStrategyKey], 'overwrite');
      expect(map.containsKey(kDownloadPathKey), false);
      expect(map.containsKey(kLegacyStreamQualityKey), false);
      expect(map.containsKey(kLegacyEnableVideoPlaybackKey), false);
    });

    test(
      'applyBackupMap restores portable keys and ignores leftovers',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        const imported = Settings(
          themeMode: ThemeMode.light,
          useDynamicColor: false,
          useAmoled: true,
          crossfadeSeconds: 11,
          restoreQueueOnStartup: false,
          autoPlayUpNext: false,
          streamAudioQuality: MediaQuality.low,
          mediaCacheSize: MediaCacheSize.mb500,
          downloadQuality: MediaQuality.mid,
          downloadOnlyOnWifi: true,
          trackHistory: false,
          checkUpdatesOnStartup: false,
          isLibraryGridView: true,
          reduceEffects: true,
          offlineMode: true,
          useVinylStyle: false,
          localSyncEnabled: true,
          localSyncAutoEnabled: true,
          playlistConflictStrategy: 'keep_local',
        );

        await container.read(settingsProvider.notifier).applyBackupMap({
          ...imported.toBackupMap(),
          kLegacyEnableVideoPlaybackKey: true,
          kDownloadPathKey: '/should/not/apply',
          kLegacyStreamQualityKey: 'high',
        });

        final settings = container.read(settingsProvider);
        expect(settings.themeMode, ThemeMode.light);
        expect(settings.useDynamicColor, false);
        expect(settings.useAmoled, true);
        expect(settings.crossfadeSeconds, 11);
        expect(settings.restoreQueueOnStartup, false);
        expect(settings.autoPlayUpNext, false);
        expect(settings.streamAudioQuality, MediaQuality.low);
        expect(settings.mediaCacheSize, MediaCacheSize.mb500);
        expect(settings.downloadQuality, MediaQuality.mid);
        expect(settings.downloadOnlyOnWifi, true);
        expect(settings.trackHistory, false);
        expect(settings.checkUpdatesOnStartup, false);
        expect(settings.isLibraryGridView, true);
        expect(settings.reduceEffects, true);
        expect(settings.offlineMode, true);
        expect(settings.useVinylStyle, false);
        expect(settings.localSyncEnabled, true);
        expect(settings.localSyncAutoEnabled, true);
        expect(settings.playlistConflictStrategy, 'keep_local');
        expect(settings.downloadPath, isNull);
      },
    );

    test('applyBackupMap accepts older streamQuality-only zips', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).applyBackupMap({
        kLegacyStreamQualityKey: 'mid',
      });
      expect(
        container.read(settingsProvider).streamAudioQuality,
        MediaQuality.mid,
      );
    });
  });

  group('Equalizer backup map', () {
    test('toBackupMap uses equalizer k*Key constants', () {
      const state = EqualizerState(
        enabled: true,
        gains: [5.0, 3.0, 0.0, 0.0, 0.0],
        preset: 'bass_boost',
      );
      final map = state.toBackupMap();
      expect(map.keys.toSet(), {
        kEqualizerEnabledKey,
        kEqualizerGainsKey,
        kEqualizerPresetKey,
      });
      expect(map[kEqualizerEnabledKey], true);
      expect(map[kEqualizerGainsKey], ['5.0', '3.0', '0.0', '0.0', '0.0']);
      expect(map[kEqualizerPresetKey], 'bass_boost');
    });

    test('parseEqualizerGains accepts list and comma-separated string', () {
      expect(parseEqualizerGains(['1.0', '2.0', '3.0', '4.0', '5.0']), [
        1.0,
        2.0,
        3.0,
        4.0,
        5.0,
      ]);
      expect(parseEqualizerGains([1, 2, 3, 4, 5]), [1.0, 2.0, 3.0, 4.0, 5.0]);
      expect(parseEqualizerGains('1,2,3,4,5'), [1.0, 2.0, 3.0, 4.0, 5.0]);
      expect(parseEqualizerGains('1,2,3'), isNull);
      expect(parseEqualizerGains(null), isNull);
    });
  });
}

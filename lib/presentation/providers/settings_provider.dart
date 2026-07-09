import 'dart:io';

import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/home/providers/home_provider.dart';
import 'ytmusic_provider.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main()');
});

class Settings {
  final ThemeMode themeMode;
  final bool useDynamicColor;
  final bool useAmoled;
  final String gl;
  final String hl;
  final int crossfadeSeconds;
  final bool restoreQueueOnStartup;
  final bool autoPlayUpNext;
  final String? downloadPath;
  final bool downloadOnlyOnWifi;
  final bool trackHistory;
  final bool checkUpdatesOnStartup;
  final bool isLibraryGridView;
  final bool reduceEffects;
  final bool offlineMode;
  final bool useVinylStyle;
  final bool localSyncEnabled;

  const Settings({
    this.themeMode = ThemeMode.system,
    this.useDynamicColor = true,
    this.useAmoled = false,
    this.gl = 'US',
    this.hl = 'en',
    this.crossfadeSeconds = 2,
    this.restoreQueueOnStartup = true,
    this.autoPlayUpNext = true,
    this.downloadPath,
    this.downloadOnlyOnWifi = false,
    this.trackHistory = true,
    this.checkUpdatesOnStartup = true,
    this.isLibraryGridView = false,
    this.reduceEffects = false,
    this.offlineMode = false,
    this.useVinylStyle = true,
    this.localSyncEnabled = false,
  });

  Settings copyWith({
    ThemeMode? themeMode,
    bool? useDynamicColor,
    bool? useAmoled,
    String? gl,
    String? hl,
    int? crossfadeSeconds,
    bool? restoreQueueOnStartup,
    bool? autoPlayUpNext,
    String? downloadPath,
    bool? downloadOnlyOnWifi,
    bool? trackHistory,
    bool? checkUpdatesOnStartup,
    bool? isLibraryGridView,
    bool? reduceEffects,
    bool? offlineMode,
    bool? useVinylStyle,
    bool? localSyncEnabled,
    bool clearDownloadPath = false,
  }) {
    return Settings(
      themeMode: themeMode ?? this.themeMode,
      useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      useAmoled: useAmoled ?? this.useAmoled,
      gl: gl ?? this.gl,
      hl: hl ?? this.hl,
      crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
      restoreQueueOnStartup:
          restoreQueueOnStartup ?? this.restoreQueueOnStartup,
      autoPlayUpNext: autoPlayUpNext ?? this.autoPlayUpNext,
      downloadPath:
          clearDownloadPath ? null : (downloadPath ?? this.downloadPath),
      downloadOnlyOnWifi: downloadOnlyOnWifi ?? this.downloadOnlyOnWifi,
      trackHistory: trackHistory ?? this.trackHistory,
      checkUpdatesOnStartup:
          checkUpdatesOnStartup ?? this.checkUpdatesOnStartup,
      isLibraryGridView: isLibraryGridView ?? this.isLibraryGridView,
      reduceEffects: reduceEffects ?? this.reduceEffects,
      offlineMode: offlineMode ?? this.offlineMode,
      useVinylStyle: useVinylStyle ?? this.useVinylStyle,
      localSyncEnabled: localSyncEnabled ?? this.localSyncEnabled,
    );
  }

  Duration get crossfadeDuration => Duration(seconds: crossfadeSeconds);
}

class SettingsNotifier extends Notifier<Settings> {
  late SharedPreferences _prefs;

  @override
  Settings build() {
    _prefs = ref.read(sharedPreferencesProvider);
    return Settings(
      themeMode: ThemeMode.values[_prefs.getInt(kThemeModeKey) ?? 0],
      useDynamicColor: _prefs.getBool(kUseDynamicColorKey) ?? true,
      useAmoled: _prefs.getBool(kUseAmoledKey) ?? false,
      gl: _prefs.getString(kGlKey) ?? 'US',
      hl: _prefs.getString(kHlKey) ?? 'en',
      crossfadeSeconds: _prefs.getInt(kCrossfadeSecondsKey) ?? 2,
      restoreQueueOnStartup: _prefs.getBool(kRestoreQueueKey) ?? true,
      autoPlayUpNext: _prefs.getBool(kAutoPlayUpNextKey) ?? true,
      downloadPath: _prefs.getString(kDownloadPathKey),
      downloadOnlyOnWifi: _prefs.getBool(kDownloadWifiKey) ?? false,
      trackHistory: _prefs.getBool(kTrackHistoryKey) ?? true,
      checkUpdatesOnStartup: _prefs.getBool(kCheckUpdatesKey) ?? true,
      isLibraryGridView: _prefs.getBool(kIsLibraryGridViewKey) ?? false,
      reduceEffects: _prefs.getBool(kReduceEffectsKey) ?? false,
      offlineMode: _prefs.getBool(kOfflineModeKey) ?? false,
      useVinylStyle: _prefs.getBool(kUseVinylStyleKey) ?? true,
      localSyncEnabled: _prefs.getBool(kLocalSyncEnabledKey) ?? false,
    );
  }

  Future<void> _save() async {
    await _prefs.setInt(kThemeModeKey, state.themeMode.index);
    await _prefs.setBool(kUseDynamicColorKey, state.useDynamicColor);
    await _prefs.setBool(kUseAmoledKey, state.useAmoled);
    await _prefs.setString(kGlKey, state.gl);
    await _prefs.setString(kHlKey, state.hl);
    await _prefs.setInt(kCrossfadeSecondsKey, state.crossfadeSeconds);
    await _prefs.setBool(kRestoreQueueKey, state.restoreQueueOnStartup);
    await _prefs.setBool(kAutoPlayUpNextKey, state.autoPlayUpNext);
    if (state.downloadPath != null) {
      await _prefs.setString(kDownloadPathKey, state.downloadPath!);
    } else {
      await _prefs.remove(kDownloadPathKey);
    }
    await _prefs.setBool(kDownloadWifiKey, state.downloadOnlyOnWifi);
    await _prefs.setBool(kTrackHistoryKey, state.trackHistory);
    await _prefs.setBool(kCheckUpdatesKey, state.checkUpdatesOnStartup);
    await _prefs.setBool(kIsLibraryGridViewKey, state.isLibraryGridView);
    await _prefs.setBool(kReduceEffectsKey, state.reduceEffects);
    await _prefs.setBool(kOfflineModeKey, state.offlineMode);
    await _prefs.setBool(kUseVinylStyleKey, state.useVinylStyle);
    await _prefs.setBool(kLocalSyncEnabledKey, state.localSyncEnabled);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _save();
  }

  Future<void> setUseDynamicColor(bool value) async {
    state = state.copyWith(useDynamicColor: value);
    await _save();
  }

  Future<void> setUseAmoled(bool value) async {
    state = state.copyWith(useAmoled: value);
    await _save();
  }

  Future<void> setGl(String gl) async {
    if (state.gl == gl) return;
    state = state.copyWith(gl: gl);
    await _save();
    await ref
        .read(ytmusicDatasourceProvider)
        .reinitialize(gl: gl, hl: state.hl);
    ref.invalidate(homeSectionsProvider);
  }

  Future<void> setHl(String hl) async {
    if (state.hl == hl) return;
    state = state.copyWith(hl: hl);
    await _save();
    await ref
        .read(ytmusicDatasourceProvider)
        .reinitialize(gl: state.gl, hl: hl);
    ref.invalidate(homeSectionsProvider);
  }

  Future<void> setCrossfadeSeconds(int seconds) async {
    state = state.copyWith(crossfadeSeconds: seconds);
    await _save();
  }

  Future<void> setRestoreQueueOnStartup(bool value) async {
    state = state.copyWith(restoreQueueOnStartup: value);
    await _save();
  }

  Future<void> setAutoPlayUpNext(bool value) async {
    state = state.copyWith(autoPlayUpNext: value);
    await _save();
  }

  Future<void> setDownloadPath(String? path) async {
    state = state.copyWith(downloadPath: path, clearDownloadPath: path == null);
    await _save();
  }

  Future<void> setDownloadOnlyOnWifi(bool value) async {
    state = state.copyWith(downloadOnlyOnWifi: value);
    await _save();
  }

  Future<void> setTrackHistory(bool value) async {
    state = state.copyWith(trackHistory: value);
    await _save();
  }

  Future<void> setCheckUpdatesOnStartup(bool value) async {
    state = state.copyWith(checkUpdatesOnStartup: value);
    await _save();
  }

  Future<void> setLibraryGridView(bool value) async {
    state = state.copyWith(isLibraryGridView: value);
    await _save();
  }

  Future<void> setReduceEffects(bool value) async {
    state = state.copyWith(reduceEffects: value);
    await _save();
  }

  Future<void> setOfflineMode(bool value) async {
    state = state.copyWith(offlineMode: value);
    await _save();
  }

  Future<void> setUseVinylStyle(bool value) async {
    state = state.copyWith(useVinylStyle: value);
    await _save();
  }

  Future<void> setLocalSyncEnabled(bool value) async {
    state = state.copyWith(localSyncEnabled: value);
    await _save();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);

// ── SharedPreferences keys ───────────────────────────────────────

const kThemeModeKey = 'themeMode';
const kUseDynamicColorKey = 'useDynamicColor';
const kUseAmoledKey = 'useAmoled';
const kGlKey = 'gl';
const kHlKey = 'hl';
const kCrossfadeSecondsKey = 'crossfadeSeconds';
const kRestoreQueueKey = 'restoreQueueOnStartup';
const kAutoPlayUpNextKey = 'autoPlayUpNext';
const kDownloadPathKey = 'downloadPath';
const kDownloadWifiKey = 'downloadOnlyOnWifi';
const kTrackHistoryKey = 'trackHistory';
const kCheckUpdatesKey = 'checkUpdatesOnStartup';
const kIsLibraryGridViewKey = 'isLibraryGridView';
const kReduceEffectsKey = 'reduceEffects';
const kOfflineModeKey = 'offlineMode';
const kUseVinylStyleKey = 'useVinylStyle';
const kLocalSyncEnabledKey = 'localSyncEnabled';
const kLastUpdateCheckTimeKey = 'lastUpdateCheckTime';

// ── Battery Optimization (Android only) ───────────────────────────

final batteryOptimizationProvider = FutureProvider<bool>((ref) async {
  if (!Platform.isAndroid) return true;
  final disabled =
      await DisableBatteryOptimization.isBatteryOptimizationDisabled;
  return disabled ?? true;
});

final manufacturerBatteryOptimizationProvider = FutureProvider<bool>((
  ref,
) async {
  if (!Platform.isAndroid) return true;
  final disabled =
      await DisableBatteryOptimization
          .isManufacturerBatteryOptimizationDisabled;
  return disabled ?? true;
});

extension BatteryOptimizationNotifier on SettingsNotifier {
  Future<void> requestDisableBatteryOptimization() async {
    await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
  }

  Future<void> requestDisableManufacturerOptimization() async {
    await DisableBatteryOptimization.showDisableManufacturerBatteryOptimizationSettings(
      'Battery Optimization',
      'Follow the steps to disable manufacturer battery optimization.',
    );
  }
}

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final sidebarCollapsedProvider =
    NotifierProvider<SidebarCollapsedNotifier, bool>(
      SidebarCollapsedNotifier.new,
    );

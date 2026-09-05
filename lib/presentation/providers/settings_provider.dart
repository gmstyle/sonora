import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/android_battery.dart';
import '../../data/services/media_cache_service.dart';
import '../../domain/models/media_cache_size.dart';
import '../../domain/models/media_quality.dart';
import '../features/home/providers/home_provider.dart';
import 'stream_datasource_provider.dart';
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
  final MediaQuality streamAudioQuality;
  final MediaCacheSize mediaCacheSize;
  final MediaQuality downloadQuality;
  final String? downloadPath;
  final bool downloadOnlyOnWifi;
  final bool trackHistory;
  final bool checkUpdatesOnStartup;
  final bool isLibraryGridView;
  final bool reduceEffects;
  final bool offlineMode;
  final bool useVinylStyle;
  final bool localSyncEnabled;
  final bool localSyncAutoEnabled;
  final String playlistConflictStrategy;

  const Settings({
    this.themeMode = ThemeMode.system,
    this.useDynamicColor = true,
    this.useAmoled = false,
    this.gl = 'US',
    this.hl = 'en',
    this.crossfadeSeconds = 2,
    this.restoreQueueOnStartup = true,
    this.autoPlayUpNext = true,
    this.streamAudioQuality = MediaQuality.high,
    this.mediaCacheSize = MediaCacheSize.gb1,
    this.downloadQuality = MediaQuality.high,
    this.downloadPath,
    this.downloadOnlyOnWifi = false,
    this.trackHistory = true,
    this.checkUpdatesOnStartup = true,
    this.isLibraryGridView = false,
    this.reduceEffects = false,
    this.offlineMode = false,
    this.useVinylStyle = true,
    this.localSyncEnabled = false,
    this.localSyncAutoEnabled = false,
    this.playlistConflictStrategy = 'merge',
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
    MediaQuality? streamAudioQuality,
    MediaCacheSize? mediaCacheSize,
    MediaQuality? downloadQuality,
    String? downloadPath,
    bool? downloadOnlyOnWifi,
    bool? trackHistory,
    bool? checkUpdatesOnStartup,
    bool? isLibraryGridView,
    bool? reduceEffects,
    bool? offlineMode,
    bool? useVinylStyle,
    bool? localSyncEnabled,
    bool? localSyncAutoEnabled,
    String? playlistConflictStrategy,
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
      streamAudioQuality: streamAudioQuality ?? this.streamAudioQuality,
      mediaCacheSize: mediaCacheSize ?? this.mediaCacheSize,
      downloadQuality: downloadQuality ?? this.downloadQuality,
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
      localSyncAutoEnabled: localSyncAutoEnabled ?? this.localSyncAutoEnabled,
      playlistConflictStrategy:
          playlistConflictStrategy ?? this.playlistConflictStrategy,
    );
  }

  Duration get crossfadeDuration => Duration(seconds: crossfadeSeconds);

  /// Portable prefs written into `backup.json` → `settings`.
  ///
  /// Excludes device-local [downloadPath] and runtime/migration keys
  /// (`lastUpdateCheckTime`, `postQueueSplitDone`,
  /// `batteryPromptDismissed`).
  Map<String, dynamic> toBackupMap() {
    return <String, dynamic>{
      kThemeModeKey: themeMode.index,
      kUseDynamicColorKey: useDynamicColor,
      kUseAmoledKey: useAmoled,
      kGlKey: gl,
      kHlKey: hl,
      kCrossfadeSecondsKey: crossfadeSeconds,
      kRestoreQueueKey: restoreQueueOnStartup,
      kAutoPlayUpNextKey: autoPlayUpNext,
      kStreamAudioQualityKey: streamAudioQuality.storageValue,
      kMediaCacheSizeKey: mediaCacheSize.storageValue,
      kDownloadQualityKey: downloadQuality.storageValue,
      kDownloadWifiKey: downloadOnlyOnWifi,
      kTrackHistoryKey: trackHistory,
      kCheckUpdatesKey: checkUpdatesOnStartup,
      kIsLibraryGridViewKey: isLibraryGridView,
      kUseVinylStyleKey: useVinylStyle,
      kReduceEffectsKey: reduceEffects,
      kOfflineModeKey: offlineMode,
      kLocalSyncEnabledKey: localSyncEnabled,
      kLocalSyncAutoEnabledKey: localSyncAutoEnabled,
      kPlaylistConflictStrategyKey: playlistConflictStrategy,
    };
  }
}

class SettingsNotifier extends Notifier<Settings> {
  late SharedPreferences _prefs;

  @override
  Settings build() {
    _prefs = ref.read(sharedPreferencesProvider);
    final settings = Settings(
      themeMode: ThemeMode.values[_prefs.getInt(kThemeModeKey) ?? 0],
      useDynamicColor: _prefs.getBool(kUseDynamicColorKey) ?? true,
      useAmoled: _prefs.getBool(kUseAmoledKey) ?? false,
      gl: _prefs.getString(kGlKey) ?? 'US',
      hl: _prefs.getString(kHlKey) ?? 'en',
      crossfadeSeconds: _prefs.getInt(kCrossfadeSecondsKey) ?? 2,
      restoreQueueOnStartup: _prefs.getBool(kRestoreQueueKey) ?? true,
      autoPlayUpNext: _prefs.getBool(kAutoPlayUpNextKey) ?? true,
      streamAudioQuality: MediaQuality.fromStorage(
        readStreamAudioQualityPref(_prefs),
      ),
      mediaCacheSize: MediaCacheSize.fromStorage(
        _prefs.getString(kMediaCacheSizeKey),
      ),
      downloadQuality: MediaQuality.fromStorage(
        _prefs.getString(kDownloadQualityKey),
      ),
      downloadPath: _prefs.getString(kDownloadPathKey),
      downloadOnlyOnWifi: _prefs.getBool(kDownloadWifiKey) ?? false,
      trackHistory: _prefs.getBool(kTrackHistoryKey) ?? true,
      checkUpdatesOnStartup: _prefs.getBool(kCheckUpdatesKey) ?? true,
      isLibraryGridView: _prefs.getBool(kIsLibraryGridViewKey) ?? false,
      reduceEffects: _prefs.getBool(kReduceEffectsKey) ?? false,
      offlineMode: _prefs.getBool(kOfflineModeKey) ?? false,
      useVinylStyle: _prefs.getBool(kUseVinylStyleKey) ?? true,
      localSyncEnabled: _prefs.getBool(kLocalSyncEnabledKey) ?? false,
      localSyncAutoEnabled: _prefs.getBool(kLocalSyncAutoEnabledKey) ?? false,
      playlistConflictStrategy:
          _prefs.getString(kPlaylistConflictStrategyKey) ?? 'merge',
    );
    MediaCacheService.instance.applyMaxCacheSizeBytes(
      settings.mediaCacheSize.bytes,
    );
    // One-shot: copy leftover `streamQuality` and drop dead keys so an
    // upgraded install keeps the user's quality without reading them again.
    unawaited(migrateLegacySettingsPrefs(_prefs));
    return settings;
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
    await _prefs.setString(
      kStreamAudioQualityKey,
      state.streamAudioQuality.storageValue,
    );
    await _prefs.setString(
      kMediaCacheSizeKey,
      state.mediaCacheSize.storageValue,
    );
    await _prefs.setString(
      kDownloadQualityKey,
      state.downloadQuality.storageValue,
    );
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
    await _prefs.setBool(kLocalSyncAutoEnabledKey, state.localSyncAutoEnabled);
    await _prefs.setString(
      kPlaylistConflictStrategyKey,
      state.playlistConflictStrategy,
    );
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
    ref.invalidate(homeBaseResultProvider);
    ref.invalidate(homeEditorialSectionsProvider);
  }

  Future<void> setHl(String hl) async {
    if (state.hl == hl) return;
    state = state.copyWith(hl: hl);
    await _save();
    await ref
        .read(ytmusicDatasourceProvider)
        .reinitialize(gl: state.gl, hl: hl);
    ref.invalidate(homeBaseResultProvider);
    ref.invalidate(homeEditorialSectionsProvider);
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

  Future<void> setStreamAudioQuality(MediaQuality value) async {
    if (state.streamAudioQuality == value) return;
    state = state.copyWith(streamAudioQuality: value);
    await _save();
    ref.read(streamDatasourceProvider).clearUrlCache();
    await MediaCacheService.instance.clearCache();
  }

  Future<void> setMediaCacheSize(MediaCacheSize value) async {
    if (state.mediaCacheSize == value) return;
    state = state.copyWith(mediaCacheSize: value);
    await _save();
    await MediaCacheService.instance.setMaxCacheSizeBytes(value.bytes);
  }

  Future<void> setDownloadQuality(MediaQuality value) async {
    if (state.downloadQuality == value) return;
    state = state.copyWith(downloadQuality: value);
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

  Future<void> setLocalSyncAutoEnabled(bool value) async {
    state = state.copyWith(localSyncAutoEnabled: value);
    await _save();
  }

  Future<void> setPlaylistConflictStrategy(String value) async {
    state = state.copyWith(playlistConflictStrategy: value);
    await _save();
  }

  /// Applies a `backup.json` settings map. Unknown keys and
  /// device-local `downloadPath` are ignored. Older zips that only
  /// have `streamQuality` still apply that value to [streamAudioQuality].
  Future<void> applyBackupMap(Map<String, dynamic> map) async {
    final themeIndex = _backupInt(map[kThemeModeKey]);
    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < ThemeMode.values.length) {
      await setThemeMode(ThemeMode.values[themeIndex]);
    }

    final useDynamicColor = _backupBool(map[kUseDynamicColorKey]);
    if (useDynamicColor != null) {
      await setUseDynamicColor(useDynamicColor);
    }

    final useAmoled = _backupBool(map[kUseAmoledKey]);
    if (useAmoled != null) {
      await setUseAmoled(useAmoled);
    }

    final gl = _backupString(map[kGlKey]);
    if (gl != null) {
      await setGl(gl);
    }

    final hl = _backupString(map[kHlKey]);
    if (hl != null) {
      await setHl(hl);
    }

    final crossfade = _backupInt(map[kCrossfadeSecondsKey]);
    if (crossfade != null) {
      await setCrossfadeSeconds(crossfade);
    }

    final restoreQueue = _backupBool(map[kRestoreQueueKey]);
    if (restoreQueue != null) {
      await setRestoreQueueOnStartup(restoreQueue);
    }

    final autoPlay = _backupBool(map[kAutoPlayUpNextKey]);
    if (autoPlay != null) {
      await setAutoPlayUpNext(autoPlay);
    }

    final audioRaw =
        _backupString(map[kStreamAudioQualityKey]) ??
        _backupString(map[kLegacyStreamQualityKey]);
    if (audioRaw != null) {
      await setStreamAudioQuality(MediaQuality.fromStorage(audioRaw));
    }

    if (map.containsKey(kMediaCacheSizeKey)) {
      await setMediaCacheSize(
        MediaCacheSize.fromStorage(_backupString(map[kMediaCacheSizeKey])),
      );
    }

    if (map.containsKey(kDownloadQualityKey)) {
      await setDownloadQuality(
        MediaQuality.fromStorage(_backupString(map[kDownloadQualityKey])),
      );
    }

    final wifiOnly = _backupBool(map[kDownloadWifiKey]);
    if (wifiOnly != null) {
      await setDownloadOnlyOnWifi(wifiOnly);
    }

    final trackHistory = _backupBool(map[kTrackHistoryKey]);
    if (trackHistory != null) {
      await setTrackHistory(trackHistory);
    }

    final checkUpdates = _backupBool(map[kCheckUpdatesKey]);
    if (checkUpdates != null) {
      await setCheckUpdatesOnStartup(checkUpdates);
    }

    final gridView = _backupBool(map[kIsLibraryGridViewKey]);
    if (gridView != null) {
      await setLibraryGridView(gridView);
    }

    final vinyl = _backupBool(map[kUseVinylStyleKey]);
    if (vinyl != null) {
      await setUseVinylStyle(vinyl);
    }

    final reduceEffects = _backupBool(map[kReduceEffectsKey]);
    if (reduceEffects != null) {
      await setReduceEffects(reduceEffects);
    }

    final offline = _backupBool(map[kOfflineModeKey]);
    if (offline != null) {
      await setOfflineMode(offline);
    }

    final localSync = _backupBool(map[kLocalSyncEnabledKey]);
    if (localSync != null) {
      await setLocalSyncEnabled(localSync);
    }

    final localSyncAuto = _backupBool(map[kLocalSyncAutoEnabledKey]);
    if (localSyncAuto != null) {
      await setLocalSyncAutoEnabled(localSyncAuto);
    }

    final conflict = _backupString(map[kPlaylistConflictStrategyKey]);
    if (conflict != null) {
      await setPlaylistConflictStrategy(conflict);
    }
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
const kLocalSyncAutoEnabledKey = 'localSyncAutoEnabled';
const kPlaylistConflictStrategyKey = 'playlistConflictStrategy';
const kCrossfadeSecondsKey = 'crossfadeSeconds';
const kRestoreQueueKey = 'restoreQueueOnStartup';
const kAutoPlayUpNextKey = 'autoPlayUpNext';
const kEqualizerEnabledKey = 'equalizerEnabled';
const kEqualizerGainsKey = 'equalizerGains';
const kEqualizerPresetKey = 'equalizerPreset';
const kStreamAudioQualityKey = 'streamAudioQuality';

/// Written by older builds; copied into [kStreamAudioQualityKey] then deleted.
const kLegacyStreamQualityKey = 'streamQuality';

/// Leftover from in-app video playback; ignored and deleted on upgrade.
const kLegacyEnableVideoPlaybackKey = 'enableVideoPlayback';

/// Quality stored as `streamAudioQuality`, or leftover `streamQuality`.
String? readStreamAudioQualityPref(SharedPreferences prefs) {
  return prefs.getString(kStreamAudioQualityKey) ??
      prefs.getString(kLegacyStreamQualityKey);
}

/// One-shot upgrade: persist the current key and drop dead leftovers.
Future<void> migrateLegacySettingsPrefs(SharedPreferences prefs) async {
  if (!prefs.containsKey(kStreamAudioQualityKey)) {
    final legacy = prefs.getString(kLegacyStreamQualityKey);
    if (legacy != null) {
      await prefs.setString(kStreamAudioQualityKey, legacy);
    }
  }
  await prefs.remove(kLegacyStreamQualityKey);
  await prefs.remove(kLegacyEnableVideoPlaybackKey);
}

const kMediaCacheSizeKey = 'mediaCacheSize';
const kDownloadQualityKey = 'downloadQuality';
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

/// Set to `true` after the queue User/UpNext split migration has run once.
/// On the first startup after the upgrade the persisted queue is cleared
/// so the new section-aware playback starts from a clean state.
const kPostQueueSplitDoneKey = 'postQueueSplitDone';

/// When `true`, the proactive battery-optimization startup prompt is never shown again.
const kBatteryPromptDismissedKey = 'batteryPromptDismissed';

/// Keys written by [Settings.toBackupMap]. Equalizer keys are merged in
/// separately from `EqualizerState.toBackupMap`.
const kSettingsBackupKeys = <String>{
  kThemeModeKey,
  kUseDynamicColorKey,
  kUseAmoledKey,
  kGlKey,
  kHlKey,
  kCrossfadeSecondsKey,
  kRestoreQueueKey,
  kAutoPlayUpNextKey,
  kStreamAudioQualityKey,
  kMediaCacheSizeKey,
  kDownloadQualityKey,
  kDownloadWifiKey,
  kTrackHistoryKey,
  kCheckUpdatesKey,
  kIsLibraryGridViewKey,
  kUseVinylStyleKey,
  kReduceEffectsKey,
  kOfflineModeKey,
  kLocalSyncEnabledKey,
  kLocalSyncAutoEnabledKey,
  kPlaylistConflictStrategyKey,
};

int? _backupInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

bool? _backupBool(Object? value) {
  if (value is bool) return value;
  return null;
}

String? _backupString(Object? value) {
  if (value is String) return value;
  return null;
}

// ── Battery Optimization (Android only) ───────────────────────────

final batteryOptimizationProvider = FutureProvider<bool>((ref) async {
  if (!Platform.isAndroid) return true;
  return AndroidBattery.isOptimizationDisabled();
});

extension BatteryOptimizationNotifier on SettingsNotifier {
  Future<void> requestDisableBatteryOptimization() async {
    await AndroidBattery.requestDisableOptimization();
  }

  Future<void> requestDisableManufacturerOptimization() async {
    await AndroidBattery.openManufacturerSettings();
  }

  Future<void> dismissBatteryPromptForever() async {
    await _prefs.setBool(kBatteryPromptDismissedKey, true);
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

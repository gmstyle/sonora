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
  final bool enableVideoPlayback;
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
    this.enableVideoPlayback = false,
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
    bool? enableVideoPlayback,
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
      enableVideoPlayback: enableVideoPlayback ?? this.enableVideoPlayback,
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
      enableVideoPlayback: _prefs.getBool(kEnableVideoPlaybackKey) ?? false,
      streamAudioQuality: MediaQuality.fromStorage(
        _prefs.getString(kStreamAudioQualityKey) ??
            _prefs.getString(kStreamQualityKey),
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
    await _prefs.setBool(kEnableVideoPlaybackKey, state.enableVideoPlayback);
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

  Future<void> setEnableVideoPlayback(bool value) async {
    if (state.enableVideoPlayback == value) return;
    state = state.copyWith(enableVideoPlayback: value);
    await _save();
    ref.read(streamDatasourceProvider).clearUrlCache();
    await MediaCacheService.instance.clearCache();
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
const kEnableVideoPlaybackKey = 'enableVideoPlayback';

/// Legacy single stream-quality key; still read as migration fallback.
const kStreamQualityKey = 'streamQuality';
const kStreamAudioQualityKey = 'streamAudioQuality';
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

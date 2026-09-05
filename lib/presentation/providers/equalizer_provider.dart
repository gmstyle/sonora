import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_provider.dart';
import 'settings_provider.dart';

const Map<String, List<double>> kEqualizerPresets = {
  'flat': [0.0, 0.0, 0.0, 0.0, 0.0],
  'bass_boost': [5.0, 3.0, 0.0, 0.0, 0.0],
  'rock': [4.0, 2.0, -1.0, 2.0, 4.0],
  'pop': [-1.0, 2.0, 4.0, 2.0, -1.0],
  'classical': [3.0, 2.0, 0.0, 2.0, 4.0],
  'vocal': [-3.0, -1.0, 4.0, 3.0, 1.0],
};

class EqualizerState {
  final bool enabled;
  final List<double> gains;
  final String preset;

  const EqualizerState({
    required this.enabled,
    required this.gains,
    required this.preset,
  });

  EqualizerState copyWith({
    bool? enabled,
    List<double>? gains,
    String? preset,
  }) {
    return EqualizerState(
      enabled: enabled ?? this.enabled,
      gains: gains ?? this.gains,
      preset: preset ?? this.preset,
    );
  }

  Map<String, dynamic> toBackupMap() {
    return <String, dynamic>{
      kEqualizerEnabledKey: enabled,
      kEqualizerGainsKey: gains.map((g) => g.toString()).toList(),
      kEqualizerPresetKey: preset,
    };
  }
}

/// Accepts a JSON list of numbers/strings or a comma-separated string.
List<double>? parseEqualizerGains(Object? raw) {
  final List<String> parts;
  if (raw is List) {
    parts = raw.map((e) => e.toString()).toList();
  } else if (raw is String) {
    parts = raw.split(',');
  } else {
    return null;
  }
  if (parts.length != 5) return null;
  return parts.map((s) => double.tryParse(s.trim()) ?? 0.0).toList();
}

class EqualizerNotifier extends Notifier<EqualizerState> {
  @override
  EqualizerState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final enabled = prefs.getBool(kEqualizerEnabledKey) ?? false;
    final gainsStr =
        prefs.getStringList(kEqualizerGainsKey) ??
        ['0.0', '0.0', '0.0', '0.0', '0.0'];
    final gains = gainsStr.map((s) => double.tryParse(s) ?? 0.0).toList();
    final preset = prefs.getString(kEqualizerPresetKey) ?? 'flat';

    // Verify the gains list is exactly 5 elements long, fallback to flat if not
    final List<double> verifiedGains;
    if (gains.length == 5) {
      verifiedGains = gains;
    } else {
      verifiedGains = List<double>.filled(5, 0.0);
    }

    return EqualizerState(
      enabled: enabled,
      gains: verifiedGains,
      preset: preset,
    );
  }

  Future<void> setEnabled(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    state = state.copyWith(enabled: value);
    await prefs.setBool(kEqualizerEnabledKey, value);
    _updateAudioHandler();
  }

  Future<void> setGain(int bandIndex, double gain) async {
    if (bandIndex < 0 || bandIndex >= 5) return;

    final newGains = List<double>.from(state.gains);
    newGains[bandIndex] = gain.clamp(-12.0, 12.0);

    final prefs = ref.read(sharedPreferencesProvider);
    state = state.copyWith(gains: newGains, preset: 'custom');
    await prefs.setStringList(
      kEqualizerGainsKey,
      newGains.map((g) => g.toString()).toList(),
    );
    await prefs.setString(kEqualizerPresetKey, 'custom');
    _updateAudioHandler();
  }

  Future<void> setPreset(String presetKey) async {
    final presetGains = kEqualizerPresets[presetKey];
    if (presetGains == null) return;

    final prefs = ref.read(sharedPreferencesProvider);
    state = state.copyWith(preset: presetKey, gains: presetGains);
    await prefs.setStringList(
      kEqualizerGainsKey,
      presetGains.map((g) => g.toString()).toList(),
    );
    await prefs.setString(kEqualizerPresetKey, presetKey);
    _updateAudioHandler();
  }

  Future<void> applyBackupMap(Map<String, dynamic> map) async {
    var enabled = state.enabled;
    var gains = List<double>.from(state.gains);
    var preset = state.preset;
    var changed = false;

    if (map[kEqualizerEnabledKey] is bool) {
      enabled = map[kEqualizerEnabledKey] as bool;
      changed = true;
    }
    final parsedGains = parseEqualizerGains(map[kEqualizerGainsKey]);
    if (parsedGains != null) {
      gains = parsedGains;
      changed = true;
    }
    if (map[kEqualizerPresetKey] is String) {
      preset = map[kEqualizerPresetKey] as String;
      changed = true;
    }
    if (!changed) return;

    final prefs = ref.read(sharedPreferencesProvider);
    state = EqualizerState(enabled: enabled, gains: gains, preset: preset);
    await prefs.setBool(kEqualizerEnabledKey, enabled);
    await prefs.setStringList(
      kEqualizerGainsKey,
      gains.map((g) => g.toString()).toList(),
    );
    await prefs.setString(kEqualizerPresetKey, preset);
    _updateAudioHandler();
  }

  void _updateAudioHandler() {
    final handler = ref.read(audioHandlerProvider);
    handler.setEqualizer(enabled: state.enabled, gains: state.gains);
  }
}

final equalizerNotifierProvider =
    NotifierProvider<EqualizerNotifier, EqualizerState>(EqualizerNotifier.new);

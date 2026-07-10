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
}

class EqualizerNotifier extends Notifier<EqualizerState> {
  @override
  EqualizerState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final enabled = prefs.getBool('equalizerEnabled') ?? false;
    final gainsStr =
        prefs.getStringList('equalizerGains') ??
        ['0.0', '0.0', '0.0', '0.0', '0.0'];
    final gains = gainsStr.map((s) => double.tryParse(s) ?? 0.0).toList();
    final preset = prefs.getString('equalizerPreset') ?? 'flat';

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
    await prefs.setBool('equalizerEnabled', value);
    _updateAudioHandler();
  }

  Future<void> setGain(int bandIndex, double gain) async {
    if (bandIndex < 0 || bandIndex >= 5) return;

    final newGains = List<double>.from(state.gains);
    newGains[bandIndex] = gain.clamp(-12.0, 12.0);

    final prefs = ref.read(sharedPreferencesProvider);
    state = state.copyWith(gains: newGains, preset: 'custom');
    await prefs.setStringList(
      'equalizerGains',
      newGains.map((g) => g.toString()).toList(),
    );
    await prefs.setString('equalizerPreset', 'custom');
    _updateAudioHandler();
  }

  Future<void> setPreset(String presetKey) async {
    final presetGains = kEqualizerPresets[presetKey];
    if (presetGains == null) return;

    final prefs = ref.read(sharedPreferencesProvider);
    state = state.copyWith(preset: presetKey, gains: presetGains);
    await prefs.setStringList(
      'equalizerGains',
      presetGains.map((g) => g.toString()).toList(),
    );
    await prefs.setString('equalizerPreset', presetKey);
    _updateAudioHandler();
  }

  void _updateAudioHandler() {
    final handler = ref.read(audioHandlerProvider);
    handler.setEqualizer(enabled: state.enabled, gains: state.gains);
  }
}

final equalizerNotifierProvider =
    NotifierProvider<EqualizerNotifier, EqualizerState>(EqualizerNotifier.new);

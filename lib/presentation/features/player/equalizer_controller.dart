import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Sonora's 5-band EQ centers (Hz), matching the in-app sliders.
const kSonoraEqualizerCentersHz = [100.0, 300.0, 1000.0, 3000.0, 10000.0];

/// Interpolates Sonora's 5 slider gains onto a device band at [freqHz].
///
/// Uses log-frequency lerp between neighboring centers so Android's native
/// band layout (often not 5 bands) still tracks the UI.
@visibleForTesting
double interpolateSonoraEqualizerGain(double freqHz, List<double> gains) {
  final g = List<double>.from(gains);
  while (g.length < 5) {
    g.add(0.0);
  }
  const centers = kSonoraEqualizerCentersHz;
  if (freqHz <= centers.first) return g.first;
  if (freqHz >= centers.last) return g[4];
  for (var i = 0; i < centers.length - 1; i++) {
    final lo = centers[i];
    final hi = centers[i + 1];
    if (freqHz <= hi) {
      final logF = math.log(freqHz);
      final t = (logF - math.log(lo)) / (math.log(hi) - math.log(lo));
      return g[i] + t * (g[i + 1] - g[i]);
    }
  }
  return 0.0;
}

/// Applies the 5-band Sonora EQ to Android's [AndroidEqualizer].
///
/// Linux uses the system equalizer (EasyEffects / Pulse / PipeWire) instead.
class EqualizerController {
  final AndroidEqualizer? _equalizer;

  EqualizerController({AndroidEqualizer? equalizer}) : _equalizer = equalizer;

  Future<void> setEqualizer({
    required bool enabled,
    required List<double> gains,
  }) async {
    if (Platform.isLinux) {
      dev.log(
        '[EqualizerController] Linux uses system EQ; skipping in-app filter',
      );
      return;
    }
    final equalizer = _equalizer;
    if (equalizer == null) {
      dev.log('[EqualizerController] No AndroidEqualizer on this platform');
      return;
    }
    try {
      await equalizer.setEnabled(enabled);
      final params = await equalizer.parameters;
      for (final band in params.bands) {
        final raw =
            enabled
                ? interpolateSonoraEqualizerGain(band.centerFrequency, gains)
                : 0.0;
        final clamped = raw.clamp(params.minDecibels, params.maxDecibels);
        await band.setGain(clamped);
      }
      dev.log(
        '[EqualizerController] Equalizer ${enabled ? 'enabled' : 'disabled'}: $gains',
      );
    } catch (e) {
      dev.log('[EqualizerController] Error applying equalizer: $e');
    }
  }
}

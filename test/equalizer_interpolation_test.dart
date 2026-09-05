import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/player/equalizer_controller.dart';

void main() {
  group('interpolateSonoraEqualizerGain', () {
    test('returns the matching slider at exact centers', () {
      const gains = [5.0, 3.0, 0.0, -2.0, 4.0];
      expect(interpolateSonoraEqualizerGain(100, gains), 5.0);
      expect(interpolateSonoraEqualizerGain(300, gains), 3.0);
      expect(interpolateSonoraEqualizerGain(1000, gains), 0.0);
      expect(interpolateSonoraEqualizerGain(3000, gains), -2.0);
      expect(interpolateSonoraEqualizerGain(10000, gains), 4.0);
    });

    test('clamps below the first center and above the last', () {
      const gains = [5.0, 0.0, 0.0, 0.0, -3.0];
      expect(interpolateSonoraEqualizerGain(20, gains), 5.0);
      expect(interpolateSonoraEqualizerGain(20000, gains), -3.0);
    });

    test('log-lerps between neighboring centers', () {
      const gains = [0.0, 10.0, 0.0, 0.0, 0.0];
      // Geometric midpoint of 100 and 300 Hz is ~173.2 Hz → t = 0.5.
      final mid = interpolateSonoraEqualizerGain(100 * math.sqrt(3), gains);
      expect(mid, closeTo(5.0, 0.05));
    });

    test('pads short gain lists with zeros', () {
      expect(interpolateSonoraEqualizerGain(10000, [2.0]), 0.0);
    });
  });
}

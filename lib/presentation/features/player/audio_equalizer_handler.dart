import 'dart:developer' as dev;
import 'package:media_kit/media_kit.dart';
import 'audio_handler.dart';

class AudioEqualizerHandler {
  final SonoraAudioHandler _audioHandler;

  AudioEqualizerHandler(this._audioHandler);

  Future<void> setEqualizer({
    required bool enabled,
    required List<double> gains,
  }) async {
    try {
      final player = _audioHandler.player;
      final playerPlatform = player.platform;

      if (playerPlatform is NativePlayer) {
        if (!enabled) {
          await playerPlatform.setProperty('af', '');
          dev.log('[AudioEqualizerHandler] Equalizer disabled');
        } else {
          final List<double> safeGains = List<double>.from(gains);
          while (safeGains.length < 5) {
            safeGains.add(0.0);
          }

          // Construct lavfi equalizer parameters
          // Center frequencies: 100 Hz, 300 Hz, 1000 Hz, 3000 Hz, 10000 Hz
          // Bandwidth width_type=q (Q-factor) is set to 1.0 to cover bands beautifully
          final filter =
              'lavfi=[equalizer=f=100:width_type=q:width=1.0:g=${safeGains[0]},'
              'equalizer=f=300:width_type=q:width=1.0:g=${safeGains[1]},'
              'equalizer=f=1000:width_type=q:width=1.0:g=${safeGains[2]},'
              'equalizer=f=3000:width_type=q:width=1.0:g=${safeGains[3]},'
              'equalizer=f=10000:width_type=q:width=1.0:g=${safeGains[4]}]';

          await playerPlatform.setProperty('af', filter);
          dev.log('[AudioEqualizerHandler] Equalizer enabled: $safeGains');
        }
      } else {
        dev.log(
          '[AudioEqualizerHandler] Player platform is not NativePlayer; equalizer not supported on this platform.',
        );
      }
    } catch (e) {
      dev.log('[AudioEqualizerHandler] Error applying equalizer filter: $e');
    }
  }
}

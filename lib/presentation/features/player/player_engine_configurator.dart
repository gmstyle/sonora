import 'dart:developer' as dev;
import 'dart:io';

import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

/// Configures the media_kit / mpv player engine (disk cache, network timeouts,
/// Linux hwdec).
class PlayerEngineConfigurator {
  final Player _player;

  PlayerEngineConfigurator({required Player player}) : _player = player;

  Future<void> configure() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/sonora_stream_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      final playerPlatform = _player.platform;
      if (playerPlatform is NativePlayer) {
        await playerPlatform.setProperty('cache', 'yes');
        await playerPlatform.setProperty('cache-on-disk', 'yes');
        await playerPlatform.setProperty('cache-dir', cacheDir.path);
        await playerPlatform.setProperty('demuxer-max-bytes', '20971520');
        await playerPlatform.setProperty('demuxer-max-back-bytes', '10485760');

        // Configure network timeout for remote HTTP streams.
        // Prevents libmpv from blocking the FFI thread for 60s when a socket dies.
        await playerPlatform.setProperty('network-timeout', '5');
        await playerPlatform.setProperty(
          'demuxer-lavf-o',
          'timeout=5000000,reconnect=1',
        );

        // Fill audio gaps with silence instead of pausing/clicking on underruns.
        // Prevents crackling when Android throttles network in background.
        await playerPlatform.setProperty('audio-stream-silence', 'yes');

        if (Platform.isLinux) {
          await playerPlatform.setProperty('hwdec', 'auto-safe');
          await playerPlatform.setProperty('vo', 'libmpv');
        }

        dev.log(
          '[AudioHandler] Stream caching configured at: ${cacheDir.path}',
        );
      }
    } catch (e) {
      dev.log('[AudioHandler] Failed to configure player caching: $e');
    }
  }
}

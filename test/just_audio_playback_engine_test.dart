import 'package:just_audio/just_audio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/player/just_audio_playback_engine.dart';
import 'package:sonora/presentation/features/player/playback_engine.dart';

void main() {
  group('JustAudioPlaybackEngine mappings', () {
    test('repeatToJa / repeatFromJa round-trip', () {
      expect(
        JustAudioPlaybackEngine.repeatToJa(EngineRepeatMode.none),
        LoopMode.off,
      );
      expect(
        JustAudioPlaybackEngine.repeatToJa(EngineRepeatMode.one),
        LoopMode.one,
      );
      expect(
        JustAudioPlaybackEngine.repeatToJa(EngineRepeatMode.all),
        LoopMode.all,
      );
      expect(
        JustAudioPlaybackEngine.repeatFromJa(LoopMode.off),
        EngineRepeatMode.none,
      );
      expect(
        JustAudioPlaybackEngine.repeatFromJa(LoopMode.one),
        EngineRepeatMode.one,
      );
      expect(
        JustAudioPlaybackEngine.repeatFromJa(LoopMode.all),
        EngineRepeatMode.all,
      );
    });

    test('toSource stores EngineMedia as the just_audio tag', () {
      const media = EngineMedia(uri: 'http://127.0.0.1:1/stream?videoId=abc');
      final source = JustAudioPlaybackEngine.toSource(media);
      expect(source, isA<UriAudioSource>());
      expect((source as UriAudioSource).uri.toString(), media.uri);
      expect(source.tag, same(media));
    });
  });
}

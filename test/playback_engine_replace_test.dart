import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/player/playback_engine.dart';

import 'helpers/fake_playback_engine.dart';

void main() {
  test('FakePlaybackEngine.replace keeps length and current index', () async {
    final engine = FakePlaybackEngine();
    await engine.open(const [
      EngineMedia(uri: 'a'),
      EngineMedia(uri: 'b'),
      EngineMedia(uri: 'c'),
    ], index: 1);

    await engine.replace(0, const EngineMedia(uri: 'a2'));

    expect(engine.playlist.medias.map((m) => m.uri), ['a2', 'b', 'c']);
    expect(engine.playlist.index, 1);
  });
}

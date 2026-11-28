import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/player/playback_engine.dart';
import 'package:sonora/presentation/features/player/playback_volume_controller.dart';

class _FakePlaybackEngine implements PlaybackEngine {
  double currentVolume = 1.0;
  PlaybackEngineState _state = const PlaybackEngineState();

  void setTestState(PlaybackEngineState next) {
    _state = next;
  }

  @override
  PlaybackEngineState get state => _state;

  @override
  Future<void> setVolume(double volume) async {
    currentVolume = volume;
  }

  @override
  Stream<bool> get playingStream => const Stream.empty();
  @override
  Stream<bool> get bufferingStream => const Stream.empty();
  @override
  Stream<bool> get completedStream => const Stream.empty();
  @override
  Stream<EnginePlaylist> get playlistStream => const Stream.empty();
  @override
  Stream<Duration> get durationStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration> get bufferedPositionStream => const Stream.empty();
  @override
  Stream<bool> get shuffleStream => const Stream.empty();
  @override
  Stream<EngineRepeatMode> get repeatModeStream => const Stream.empty();
  @override
  Stream<String> get errorStream => const Stream.empty();

  @override
  Future<void> open(
    List<EngineMedia> medias, {
    int index = 0,
    bool play = true,
    Duration position = Duration.zero,
  }) async {}

  @override
  Future<void> add(EngineMedia media) async {}

  @override
  Future<void> remove(int index) async {}

  @override
  Future<void> replace(int index, EngineMedia media) async {}

  @override
  Future<void> move(int from, int to) async {}

  @override
  Future<void> jump(int index) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setShuffle(bool enabled) async {}

  @override
  Future<void> setRepeatMode(EngineRepeatMode mode) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  group('PlaybackVolumeController', () {
    test('setUserVolume and setMuted update effective volume', () {
      final engine = _FakePlaybackEngine();
      final controller = PlaybackVolumeController(
        engine: engine,
        isCastConnected: () => false,
      );

      controller.setUserVolume(0.5);
      expect(controller.userVolume, 0.5);
      expect(controller.isMuted, isFalse);
      expect(engine.currentVolume, closeTo(0.5, 0.001));

      controller.setMuted(true);
      expect(controller.isMuted, isTrue);
      expect(controller.effectiveVolume, 0.0);
      expect(engine.currentVolume, 0.0);

      controller.setMuted(false);
      expect(controller.isMuted, isFalse);
      expect(engine.currentVolume, closeTo(0.5, 0.001));
    });

    test('crossfade scales by userVolume instead of resetting to 1.0', () {
      final engine = _FakePlaybackEngine();
      engine.setTestState(
        const PlaybackEngineState(
          playing: true,
          duration: Duration(seconds: 100),
        ),
      );
      final controller = PlaybackVolumeController(
        engine: engine,
        isCastConnected: () => false,
      );

      controller.setUserVolume(0.4);
      controller.setCrossfadeDuration(const Duration(seconds: 4));

      // Mid-fade-in at 2s of 4s => 50% of userVolume (0.4) = 0.2.
      controller.beginFadeIn();
      expect(engine.currentVolume, 0.0);
      controller.handleCrossfade(const Duration(seconds: 2));
      expect(engine.currentVolume, closeTo(0.2, 0.001));

      // Fade-in complete => full userVolume (0.4), never 1.0.
      controller.handleCrossfade(const Duration(seconds: 5));
      expect(engine.currentVolume, closeTo(0.4, 0.001));
      expect(controller.userVolume, 0.4);
    });
  });
}

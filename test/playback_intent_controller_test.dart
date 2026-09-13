import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/player/playback_intent_controller.dart';

/// Characterisation tests for the playback-intent rules that used to live as
/// flags inside `SonoraAudioHandler`.
void main() {
  late PlaybackIntentController intent;

  setUp(() => intent = PlaybackIntentController());

  /// Mirrors `SonoraAudioHandler.play()`.
  void play() => intent.onPlayAccepted();

  /// Mirrors `_pause()` after in-app or MediaSession pause.
  void pause() => intent.onPauseApplied();

  /// Mirrors the `player.stream.playing` listener.
  void engineReports(bool playing, {bool suppressClear = false}) {
    intent.onEnginePlaying(playing, suppressClear: suppressClear);
  }

  group('initial state', () {
    test('starts idle, wanting nothing', () {
      expect(intent.userWantsPlaying, isFalse);
      expect(intent.intent, PlaybackIntent.idle);
    });

    test('the first play sets the intent', () {
      play();
      expect(intent.userWantsPlaying, isTrue);
      expect(intent.intent, PlaybackIntent.wantsPlaying);
    });
  });

  group('MediaSession PLAY', () {
    test('pause still resumes on PLAY (standard contract)', () {
      play();
      pause();

      expect(intent.userWantsPlaying, isFalse);
      expect(intent.intent, PlaybackIntent.idle);

      play();
      expect(intent.userWantsPlaying, isTrue);
      expect(intent.intent, PlaybackIntent.wantsPlaying);
    });

    test('play is accepted when audio is already running', () {
      play();
      play();
      expect(intent.userWantsPlaying, isTrue);
    });
  });

  group('notification and headset pause', () {
    test('a headset tap after pause resumes', () {
      play();
      pause();

      expect(intent.userWantsPlaying, isFalse);
      play();
      expect(intent.userWantsPlaying, isTrue);
    });
  });

  group('interruptions', () {
    test('interruption pause then resume restores the intent', () {
      play();
      intent.onPauseApplied();
      expect(intent.userWantsPlaying, isFalse);

      play();
      expect(intent.userWantsPlaying, isTrue);
    });
  });

  group('engine reports', () {
    test('playing true sets the intent', () {
      engineReports(true);
      expect(intent.userWantsPlaying, isTrue);
    });

    test('playing false clears the intent', () {
      play();
      engineReports(false);
      expect(intent.userWantsPlaying, isFalse);
    });

    test('playing false is ignored while restoring', () {
      play();
      engineReports(false, suppressClear: true);
      expect(intent.userWantsPlaying, isTrue);
    });

    test('playing false is ignored during a muted track transition', () {
      play();
      engineReports(false, suppressClear: true);
      expect(intent.userWantsPlaying, isTrue);
    });

    test('playing false is ignored while pausing for a cast handover', () {
      play();
      engineReports(false, suppressClear: true);
      expect(intent.userWantsPlaying, isTrue);
    });
  });

  group('cold-start restore', () {
    test('publishes paused without arming the intent', () {
      intent.setUserWantsPlaying(false);

      expect(intent.userWantsPlaying, isFalse);
      expect(intent.intent, PlaybackIntent.idle);
    });

    test('a restore that should resume seeds the intent', () {
      intent.setUserWantsPlaying(true);
      expect(intent.userWantsPlaying, isTrue);
    });

    test('restore does not block a later play', () {
      intent.setUserWantsPlaying(false);
      play();
      expect(intent.userWantsPlaying, isTrue);
    });
  });

  group('queue transitions', () {
    test('setQueue opens paused', () {
      play();
      intent.onQueueReplaced();

      expect(intent.userWantsPlaying, isFalse);
    });

    test('playNow after a pause starts a new session', () {
      play();
      pause();
      expect(intent.userWantsPlaying, isFalse);

      intent.onPlayAccepted();
      expect(intent.userWantsPlaying, isTrue);
    });

    test('clearQueue drops the intent', () {
      play();
      intent.onQueueCleared();
      expect(intent.userWantsPlaying, isFalse);
    });
  });

  group('stop', () {
    test('ends the session; a later PLAY still starts', () {
      play();
      intent.onStop();

      expect(intent.userWantsPlaying, isFalse);
      play();
      expect(intent.userWantsPlaying, isTrue);
    });

    test('playNow after stop starts a fresh session', () {
      play();
      intent.onStop();

      intent.onPlayAccepted();

      expect(intent.userWantsPlaying, isTrue);
    });
  });
}

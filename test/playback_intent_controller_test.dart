import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/player/playback_intent_controller.dart';

/// Characterisation tests for the playback-intent rules that used to live as
/// three booleans inside `SonoraAudioHandler`. Each scenario mirrors a real bug
/// the original flags were introduced to fix, so these must keep passing.
void main() {
  late PlaybackIntentController intent;

  setUp(() => intent = PlaybackIntentController());

  /// Mirrors `SonoraAudioHandler.play()`.
  bool play({bool engineIsPlaying = false}) {
    if (intent.shouldRejectPlay(engineIsPlaying: engineIsPlaying)) return false;
    intent.onPlayAccepted();
    return true;
  }

  /// Mirrors `pauseFromUser()` followed by `_pause()`.
  void pauseFromUser() {
    intent.onUserPause();
    intent.onPauseApplied();
  }

  /// Mirrors the MediaSession `pause()` override followed by `_pause()`.
  void pauseFromSession() {
    intent.onSessionPause();
    intent.onPauseApplied();
  }

  /// Mirrors the `player.stream.playing` listener.
  void engineReports(bool playing, {bool suppressClear = false}) {
    if (intent.shouldForcePause(playing: playing)) return;
    intent.onEnginePlaying(playing, suppressClear: suppressClear);
  }

  group('initial state', () {
    test('starts idle, wanting nothing', () {
      expect(intent.userWantsPlaying, isFalse);
      expect(intent.isExplicitlyPaused, isFalse);
      expect(intent.intent, PlaybackIntent.idle);
    });

    test('does not reject the first play', () {
      expect(play(), isTrue);
      expect(intent.userWantsPlaying, isTrue);
      expect(intent.intent, PlaybackIntent.wantsPlaying);
    });
  });

  group('Pixel Buds ear-detection', () {
    test('in-app pause rejects the spurious PLAY that follows', () {
      play();
      pauseFromUser();

      expect(intent.isExplicitlyPaused, isTrue);
      expect(intent.intent, PlaybackIntent.pausedByUser);

      // Buds are put back on and the MediaSession sends PLAY unprompted.
      expect(play(), isFalse, reason: 'ear-detection PLAY must be ignored');
      expect(intent.userWantsPlaying, isFalse);
    });

    test('the engine starting anyway is pushed back to paused', () {
      play();
      pauseFromUser();

      expect(intent.shouldForcePause(playing: true), isTrue);

      engineReports(true);
      expect(intent.userWantsPlaying, isFalse, reason: 'guard ran first');
    });

    test('a deliberate in-app resume is not rejected', () async {
      play();
      pauseFromUser();

      final resumed = await intent.runAuthorizedResume(() async => play());

      expect(resumed, isTrue);
      expect(intent.userWantsPlaying, isTrue);
      expect(intent.isExplicitlyPaused, isFalse);
    });

    test('the authorised window closes again afterwards', () async {
      play();
      pauseFromUser();
      await intent.runAuthorizedResume(() async => play());
      expect(intent.isResumeAuthorized, isFalse);

      pauseFromUser();
      expect(play(), isFalse, reason: 'guard is active again');
    });

    test('play is accepted when audio is already running', () {
      // An explicit pause that never reached the engine must not swallow a
      // genuine play: shouldRejectPlay only fires when the engine is idle.
      play();
      intent.onUserPause();

      expect(play(engineIsPlaying: true), isTrue);
      expect(intent.isExplicitlyPaused, isFalse);
    });
  });

  group('notification and headset pause', () {
    test('does not mark an explicit pause, so a headset tap resumes', () {
      play();
      pauseFromSession();

      expect(intent.isExplicitlyPaused, isFalse);
      expect(intent.userWantsPlaying, isFalse);

      expect(play(), isTrue, reason: 'headset tap must resume');
      expect(intent.userWantsPlaying, isTrue);
    });

    test('an in-app pause after a session pause still guards', () {
      play();
      pauseFromSession();
      pauseFromUser();

      expect(play(), isFalse);
    });
  });

  group('audio focus', () {
    test('a denied focus request leaves the user not wanting playback', () {
      play();
      expect(intent.userWantsPlaying, isTrue);

      intent.onFocusDenied();
      expect(intent.userWantsPlaying, isFalse);
    });

    test('interruption pause then resume restores the intent', () {
      // Assistant/Gemini takes focus: audio_session pauses through _pause().
      play();
      intent.onPauseApplied();
      expect(intent.userWantsPlaying, isFalse);

      // Interruption ends and the session controller calls play().
      expect(play(), isTrue, reason: 'no explicit pause was recorded');
      expect(intent.userWantsPlaying, isTrue);
    });

    test('an interruption during an in-app pause does not auto-resume', () {
      play();
      pauseFromUser();
      intent.onPauseApplied();

      expect(play(), isFalse);
    });
  });

  group('becoming noisy', () {
    test('unplugging headphones pauses without arming a resume', () {
      play();
      // AudioSessionController clears its own resume flag and calls _pause().
      intent.onPauseApplied();

      expect(intent.userWantsPlaying, isFalse);
      expect(intent.isExplicitlyPaused, isFalse);
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
      // PlaybackRestoreController seeds the intent directly.
      intent.setUserWantsPlaying(false);

      expect(intent.userWantsPlaying, isFalse);
      expect(intent.isExplicitlyPaused, isFalse);
      expect(intent.intent, PlaybackIntent.idle);
    });

    test('a restore that should resume seeds the intent', () {
      intent.setUserWantsPlaying(true);
      expect(intent.userWantsPlaying, isTrue);
    });

    test('restore does not block a later play', () {
      intent.setUserWantsPlaying(false);
      expect(play(), isTrue);
    });
  });

  group('queue transitions', () {
    test('setQueue opens paused', () {
      play();
      intent.onQueueReplaced();

      expect(intent.userWantsPlaying, isFalse);
      expect(intent.isExplicitlyPaused, isFalse);
    });

    test('playNow clears a pause left by playAlbum', () {
      // playAlbum pauses through pauseFromUser() before building the queue.
      play();
      pauseFromUser();
      expect(intent.isExplicitlyPaused, isTrue);

      intent.onNewSessionStarted();
      expect(
        intent.isExplicitlyPaused,
        isFalse,
        reason: 'otherwise the engine immediately pauses the new playlist',
      );

      intent.onSessionOpened(hasFocus: true);
      expect(intent.userWantsPlaying, isTrue);
    });

    test('playNow without focus opens paused', () {
      intent.onNewSessionStarted();
      intent.onSessionOpened(hasFocus: false);

      expect(intent.userWantsPlaying, isFalse);
    });

    test('clearQueue drops the intent', () {
      play();
      intent.onQueueCleared();
      expect(intent.userWantsPlaying, isFalse);
    });
  });

  group('stop', () {
    test('ends the session and guards against unsolicited PLAY', () {
      play();
      intent.onStop();

      expect(intent.userWantsPlaying, isFalse);
      expect(intent.isExplicitlyPaused, isTrue);
      expect(play(), isFalse);
    });

    test('playNow after stop starts a fresh session', () {
      play();
      intent.onStop();

      intent.onNewSessionStarted();
      intent.onSessionOpened(hasFocus: true);

      expect(intent.userWantsPlaying, isTrue);
      expect(intent.isExplicitlyPaused, isFalse);
    });
  });
}

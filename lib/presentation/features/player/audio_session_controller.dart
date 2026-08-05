import 'dart:async';
import 'dart:developer' as dev;

import 'package:audio_session/audio_session.dart';

/// Owns OS audio-session / focus lifecycle for the player.
///
/// Handles interruption events, becoming-noisy, and focus request/release.
/// Does not hold a back-reference to [SonoraAudioHandler]; callers inject
/// narrow callbacks instead.
class AudioSessionController {
  final bool Function() _userWantsPlaying;
  final bool Function() _isPlaying;
  final FutureOr<void> Function() _onPauseRequested;
  final FutureOr<void> Function() _onResumeRequested;
  final void Function(bool ducking) _onDuck;

  bool _playOnInterruptionEnd = false;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;

  AudioSessionController({
    required bool Function() userWantsPlaying,
    required bool Function() isPlaying,
    required FutureOr<void> Function() onPauseRequested,
    required FutureOr<void> Function() onResumeRequested,
    required void Function(bool ducking) onDuck,
  }) : _userWantsPlaying = userWantsPlaying,
       _isPlaying = isPlaying,
       _onPauseRequested = onPauseRequested,
       _onResumeRequested = onResumeRequested,
       _onDuck = onDuck;

  /// Clears the auto-resume-on-interruption-end flag.
  /// Called from play / pause / stop / becoming-noisy.
  void cancelResumeOnInterruptionEnd() {
    _playOnInterruptionEnd = false;
  }

  Future<void> setup() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _interruptionSub = session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // Only mark for auto-resume if the user actually wants playback active.
              // If the user explicitly paused (e.g. via earbud tap), _userWantsPlaying is false.
              _playOnInterruptionEnd = _userWantsPlaying() && _isPlaying();
              _onPauseRequested();
              break;
            case AudioInterruptionType.duck:
              _onDuck(true);
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // Resume solely from the interruption flag. `_pause()` (and the
              // playing stream) clear `_userWantsPlaying`, so gating on it
              // here permanently blocked auto-resume after Gemini/Assistant.
              if (_playOnInterruptionEnd) {
                _onResumeRequested();
              }
              _playOnInterruptionEnd = false;
              break;
            case AudioInterruptionType.duck:
              _onDuck(false);
              break;
          }
        }
      });
      _becomingNoisySub = session.becomingNoisyEventStream.listen((_) {
        dev.log(
          '[AudioHandler] Headphones unplugged / Becoming Noisy -> pausing playback',
        );
        _playOnInterruptionEnd = false;
        _onPauseRequested();
      });
    } catch (e) {
      dev.log('[AudioHandler] Failed to configure audio session: $e');
    }
  }

  Future<bool> requestFocus() async {
    try {
      final session = await AudioSession.instance;
      return await session.setActive(true);
    } catch (e) {
      dev.log('[AudioHandler] Failed to request audio focus: $e');
      return false;
    }
  }

  Future<void> releaseFocus() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      dev.log('[AudioHandler] Failed to release audio focus: $e');
    }
  }

  void dispose() {
    _interruptionSub?.cancel();
    _becomingNoisySub?.cancel();
  }
}

import 'dart:async';
import 'dart:developer' as dev;

import 'package:audio_session/audio_session.dart';

/// Configures the shared [AudioSession] and covers the one case `just_audio`
/// cannot: Chromecast / DLNA, where the local engine is paused.
///
/// Official `just_audio` + `audio_service` setup:
/// - `AudioPlayer()` keeps `handleInterruptions` / `handleAudioSessionActivation`
///   / `androidApplyAudioAttributes` at their defaults (`true`).
/// - Call [configure] once with [AudioSessionConfiguration.music].
/// - Do **not** activate, pause, or duck locally — `just_audio` does that.
/// - Do **not** `setActive(false)` on pause or stop (`just_audio` never does).
///
/// Cast is the documented exception: the audio plugin is not playing, so
/// [requestFocus] (`setActive(true)`) and interruption pause/resume must be
/// applied to the remote session instead.
class AudioSessionController {
  final bool Function() _userWantsPlaying;
  final bool Function() _isRemotePlaying;
  final bool Function() _isRemotePlayback;
  final FutureOr<void> Function() _onPauseRequested;
  final FutureOr<void> Function() _onResumeRequested;

  bool _playOnInterruptionEnd = false;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;

  AudioSessionController({
    required bool Function() userWantsPlaying,
    required bool Function() isRemotePlaying,
    required bool Function() isRemotePlayback,
    required FutureOr<void> Function() onPauseRequested,
    required FutureOr<void> Function() onResumeRequested,
  }) : _userWantsPlaying = userWantsPlaying,
       _isRemotePlaying = isRemotePlaying,
       _isRemotePlayback = isRemotePlayback,
       _onPauseRequested = onPauseRequested,
       _onResumeRequested = onResumeRequested;

  void cancelResumeOnInterruptionEnd() {
    _playOnInterruptionEnd = false;
  }

  Future<void> setup() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _interruptionSub = session.interruptionEventStream.listen(
        handleInterruption,
      );
    } catch (e) {
      dev.log('[AudioHandler] Failed to configure audio session: $e');
    }
  }

  /// Local playback is owned by `just_audio` (`handleInterruptions: true`).
  /// This only forwards pause/resume while Cast is connected.
  void handleInterruption(AudioInterruptionEvent event) {
    if (!_isRemotePlayback()) return;
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          _playOnInterruptionEnd = _userWantsPlaying() && _isRemotePlaying();
          _onPauseRequested();
          break;
        case AudioInterruptionType.duck:
          break;
      }
    } else {
      switch (event.type) {
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          if (_playOnInterruptionEnd) {
            _onResumeRequested();
          }
          _playOnInterruptionEnd = false;
          break;
        case AudioInterruptionType.duck:
          break;
      }
    }
  }

  /// `just_audio` is not playing during Cast, so it will not activate the
  /// session. [audio_session] documents `setActive(true)` for that case.
  Future<bool> requestFocus() async {
    try {
      final session = await AudioSession.instance;
      return await session.setActive(true);
    } catch (e) {
      dev.log('[AudioHandler] Failed to request audio focus: $e');
      return false;
    }
  }

  void dispose() {
    _interruptionSub?.cancel();
  }
}

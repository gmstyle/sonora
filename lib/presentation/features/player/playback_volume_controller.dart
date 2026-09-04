import 'playback_engine.dart';

/// Owns the player's output volume: crossfade envelope, transition mute and
/// the cast-aware local volume application.
///
/// Volume is always in the 0..1 range. Does not hold a back-reference to
/// [SonoraAudioHandler]; the cast state is injected as the narrow
/// [isCastConnected] predicate.
class PlaybackVolumeController {
  final PlaybackEngine _engine;
  final bool Function() _isCastConnected;

  Duration _crossfadeDuration = Duration.zero;
  bool _isFadingIn = false;
  double _lastSetVolume = 1.0;
  bool _isTransitionMuted = false;

  PlaybackVolumeController({
    required PlaybackEngine engine,
    required bool Function() isCastConnected,
  }) : _engine = engine,
       _isCastConnected = isCastConnected;

  /// True while a track transition is muted, i.e. between
  /// [prepareTransitionMute] and [endTransitionMute]. Read by the `playing`
  /// and `position` listeners.
  bool get isTransitionMuted => _isTransitionMuted;

  /// The last logical volume applied by the crossfade envelope, in the 0..1
  /// range. Read by [CastPlaybackController] to restore volume on disconnect.
  double get lastSetVolume => _lastSetVolume;

  void setCrossfadeDuration(Duration duration) {
    _crossfadeDuration = duration;
    if (duration == Duration.zero) _applyVolume(1.0);
  }

  void prepareTransitionMute() {
    if (_engine.state.playlist.medias.isNotEmpty) {
      _isTransitionMuted = true;
      setLocalVolume(0.0, force: true);
    }
  }

  void endTransitionMute() {
    if (!_isTransitionMuted) return;

    setLocalVolume(_lastSetVolume);
    _isTransitionMuted = false;
  }

  void setLocalVolume(double volume, {bool force = false}) {
    final v = volume.clamp(0.0, 1.0);
    if (!force && _isCastConnected()) {
      unawaitedSetVolume(0.0);
    } else {
      unawaitedSetVolume(v);
    }
  }

  void unawaitedSetVolume(double volume) {
    _engine.setVolume(volume);
  }

  void _applyVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
    if ((v - _lastSetVolume).abs() > 0.005) {
      _lastSetVolume = v;
      if (!_isTransitionMuted) {
        setLocalVolume(v);
      }
    }
  }

  /// Applies (or lifts) the OS-requested transient volume duck.
  void setDucking(bool ducking) {
    setLocalVolume(_lastSetVolume * (ducking ? 0.2 : 1.0));
  }

  /// Arms a fade-in from silence for the track that just became current.
  /// No-op when crossfade is disabled or the player is not playing.
  void beginFadeIn() {
    if (_crossfadeDuration > Duration.zero && _engine.state.playing) {
      _isFadingIn = true;
      _applyVolume(0.0);
    }
  }

  void handleCrossfade(Duration position) {
    if (_crossfadeDuration == Duration.zero) return;
    final duration = _engine.state.duration;
    if (duration == Duration.zero || !_engine.state.playing) return;

    if (_isFadingIn) {
      final fadeMs = _crossfadeDuration.inMilliseconds;
      final vol = fadeMs > 0 ? position.inMilliseconds / fadeMs : 1.0;
      if (vol >= 1.0) {
        _applyVolume(1.0);
        _isFadingIn = false;
      } else {
        _applyVolume(vol);
      }
      return;
    }

    final remaining = duration - position;
    if (remaining > Duration.zero && remaining <= _crossfadeDuration) {
      _applyVolume(
        remaining.inMilliseconds / _crossfadeDuration.inMilliseconds,
      );
    } else if (remaining > _crossfadeDuration) {
      _applyVolume(1.0);
    }
  }
}

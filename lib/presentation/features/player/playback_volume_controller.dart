import 'playback_engine.dart';

/// Owns the player's output volume: master user volume, mute state, crossfade
/// envelope, transition mute and the cast-aware local volume application.
///
/// Volume is always in the 0..1 range. Does not hold a back-reference to
/// [SonoraAudioHandler]; the cast state is injected as the narrow
/// [isCastConnected] predicate.
class PlaybackVolumeController {
  final PlaybackEngine _engine;
  final bool Function() _isCastConnected;

  Duration _crossfadeDuration = Duration.zero;
  bool _isFadingIn = false;
  double _userVolume = 1.0;
  bool _isMuted = false;
  double _fadeFactor = 1.0;
  double _lastAppliedVolume = 1.0;
  bool _isTransitionMuted = false;

  PlaybackVolumeController({
    required this._engine,
    required this._isCastConnected,
  });

  /// True while a track transition is muted, i.e. between
  /// [prepareTransitionMute] and [endTransitionMute]. Read by the `playing`
  /// and `position` listeners.
  bool get isTransitionMuted => _isTransitionMuted;

  /// Master user volume in the 0..1 range.
  double get userVolume => _userVolume;

  /// Whether output audio is muted by the user.
  bool get isMuted => _isMuted;

  /// Effective output volume combining [userVolume], [isMuted], and the
  /// active crossfade envelope.
  double get effectiveVolume =>
      _isMuted ? 0.0 : (_userVolume * _fadeFactor).clamp(0.0, 1.0);

  /// The last logical volume applied by the volume/crossfade envelope, in the
  /// 0..1 range. Read by [CastPlaybackController] to restore volume on disconnect.
  double get lastSetVolume => effectiveVolume;

  void setUserVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
    _userVolume = v;
    _isMuted = v <= 0.0;
    _applyEffectiveVolume(force: true);
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    _applyEffectiveVolume(force: true);
  }

  void setCrossfadeDuration(Duration duration) {
    _crossfadeDuration = duration;
    if (duration == Duration.zero) _applyFade(1.0);
  }

  void prepareTransitionMute() {
    if (_engine.state.playlist.medias.isNotEmpty) {
      _isTransitionMuted = true;
      setLocalVolume(0.0, force: true);
    }
  }

  void endTransitionMute() {
    if (!_isTransitionMuted) return;

    _isTransitionMuted = false;
    _lastAppliedVolume = effectiveVolume;
    setLocalVolume(effectiveVolume);
  }

  void setLocalVolume(double volume, {bool force = false}) {
    final v = volume.clamp(0.0, 1.0);
    final castConnected = _isCastConnected();
    if (!force && castConnected) {
      unawaitedSetVolume(0.0);
    } else {
      unawaitedSetVolume(v);
    }
  }

  void unawaitedSetVolume(double volume) {
    _engine.setVolume(volume);
  }

  void _applyFade(double factor) {
    _fadeFactor = factor.clamp(0.0, 1.0);
    _applyEffectiveVolume();
  }

  void _applyEffectiveVolume({bool force = false}) {
    final target = effectiveVolume;
    if (force || (target - _lastAppliedVolume).abs() > 0.005) {
      _lastAppliedVolume = target;
      if (!_isTransitionMuted) {
        setLocalVolume(target);
      }
    }
  }

  /// Arms a fade-in from silence for the track that just became current.
  /// No-op when crossfade is disabled or the player is not playing.
  void beginFadeIn() {
    if (_crossfadeDuration > Duration.zero && _engine.state.playing) {
      _isFadingIn = true;
      _applyFade(0.0);
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
        _applyFade(1.0);
        _isFadingIn = false;
      } else {
        _applyFade(vol);
      }
      return;
    }

    final remaining = duration - position;
    if (remaining > Duration.zero && remaining <= _crossfadeDuration) {
      _applyFade(remaining.inMilliseconds / _crossfadeDuration.inMilliseconds);
    } else if (remaining > _crossfadeDuration) {
      _applyFade(1.0);
    }
  }
}

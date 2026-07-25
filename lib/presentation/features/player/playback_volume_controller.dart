import 'package:media_kit/media_kit.dart';

/// Owns the player's output volume: crossfade envelope, transition mute and
/// the cast-aware local volume application.
///
/// Does not hold a back-reference to [SonoraAudioHandler]; the cast state is
/// injected as the narrow [isCastConnected] predicate.
class PlaybackVolumeController {
  final Player _player;
  final bool Function() _isCastConnected;

  Duration _crossfadeDuration = Duration.zero;
  bool _isFadingIn = false;
  double _lastSetVolume = 1.0;
  bool _isTransitionMuted = false;

  PlaybackVolumeController({
    required Player player,
    required bool Function() isCastConnected,
  }) : _player = player,
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
    if (_player.state.playlist.medias.isNotEmpty) {
      _isTransitionMuted = true;
      setLocalVolume(0.0, force: true);
    }
  }

  void endTransitionMute() {
    if (!_isTransitionMuted) return;

    setLocalVolume(_lastSetVolume * 100.0);
    _isTransitionMuted = false;
  }

  void setLocalVolume(double volume, {bool force = false}) {
    if (!force && _isCastConnected()) {
      _player.setVolume(0.0);
    } else {
      _player.setVolume(volume);
    }
  }

  void _applyVolume(double volume) {
    final v = volume.clamp(0.0, 1.0);
    if ((v - _lastSetVolume).abs() > 0.005) {
      _lastSetVolume = v;
      if (!_isTransitionMuted) {
        setLocalVolume(v * 100.0);
      }
    }
  }

  /// Applies (or lifts) the OS-requested transient volume duck.
  void setDucking(bool ducking) {
    setLocalVolume(_lastSetVolume * (ducking ? 20.0 : 100.0));
  }

  /// Arms a fade-in from silence for the track that just became current.
  /// No-op when crossfade is disabled or the player is not playing.
  void beginFadeIn() {
    if (_crossfadeDuration > Duration.zero && _player.state.playing) {
      _isFadingIn = true;
      _applyVolume(0.0);
    }
  }

  void handleCrossfade(Duration position) {
    if (_crossfadeDuration == Duration.zero) return;
    final duration = _player.state.duration;
    if (duration == Duration.zero || !_player.state.playing) return;

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

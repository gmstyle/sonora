import 'package:media_kit/media_kit.dart';

/// Attaches (or clears) an external audio track for dual-file video cache hits.
///
/// Pair playback uses [AudioTrack.uri] (`audio-add`). HLS, muxed files, and
/// audio-only tracks must reset to [AudioTrack.auto] so they do not inherit
/// the previous video's external audio.
class ExternalAudioTrackController {
  static const extraKey = 'externalAudioUri';

  final Player _player;
  int _generation = 0;

  ExternalAudioTrackController({required Player player}) : _player = player;

  /// Applies [media]'s `extras['externalAudioUri']`, or resets to auto.
  ///
  /// Stale calls are ignored when a newer [attachForMedia] has already started
  /// (user skipped before the previous attach settled).
  Future<void> attachForMedia(Media? media) async {
    final gen = ++_generation;
    final uri = media?.extras?[extraKey] as String?;
    if (gen != _generation) return;
    if (uri != null && uri.isNotEmpty) {
      await _player.setAudioTrack(AudioTrack.uri(uri));
    } else {
      await _player.setAudioTrack(AudioTrack.auto());
    }
  }
}

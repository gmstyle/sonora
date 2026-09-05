import 'playback_engine.dart';

/// Attaches (or clears) an external audio track for dual-file video cache hits.
///
/// Pair playback uses [PlaybackEngine.attachExternalAudio]. HLS, muxed files,
/// and audio-only tracks must reset to auto so they do not inherit the previous
/// video's external audio.
class ExternalAudioTrackController {
  static const extraKey = kExternalAudioUriExtraKey;

  final PlaybackEngine _engine;
  int _generation = 0;

  ExternalAudioTrackController({required PlaybackEngine engine})
    : _engine = engine;

  /// Applies [media]'s sidecar audio URI, or resets to auto.
  ///
  /// Stale calls are ignored when a newer [attachForMedia] has already started
  /// (user skipped before the previous attach settled).
  Future<void> attachForMedia(EngineMedia? media) async {
    final gen = ++_generation;
    final uri = media?.externalAudioUri;
    if (gen != _generation) return;
    await _engine.attachExternalAudio(
      (uri != null && uri.isNotEmpty) ? uri : null,
    );
  }
}

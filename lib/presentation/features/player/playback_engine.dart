import 'package:audio_service/audio_service.dart';

/// Repeat mode exposed by [PlaybackEngine], independent of the audio backend.
enum EngineRepeatMode { none, one, all }

/// Engine URI used when the local proxy is down and the track has no stream URL
/// yet. Production just_audio maps this to a silent source so ExoPlayer never
/// fetches a fake `.wav`.
const kPlaceholderAudioUriPrefix = 'http://localhost/dummy_';

/// True when [uri] is empty or the dummy placeholder, not a playable proxy/file.
bool isPlaceholderAudioUri(String uri) =>
    uri.isEmpty || uri.startsWith(kPlaceholderAudioUriPrefix);

/// One playlist entry for [PlaybackEngine].
///
/// [mediaItem] is the audio_service identity for the slot.
class EngineMedia {
  final String uri;
  final MediaItem? mediaItem;

  const EngineMedia({required this.uri, this.mediaItem});

  EngineMedia copyWith({String? uri, MediaItem? mediaItem}) {
    return EngineMedia(
      uri: uri ?? this.uri,
      mediaItem: mediaItem ?? this.mediaItem,
    );
  }
}

/// Snapshot of the engine playlist (current index + ordered sources).
class EnginePlaylist {
  final int index;
  final List<EngineMedia> medias;

  const EnginePlaylist({this.index = 0, this.medias = const []});

  bool get isEmpty => medias.isEmpty;

  int get length => medias.length;

  MediaItem? mediaItemAt(int i) {
    if (i < 0 || i >= medias.length) return null;
    return medias[i].mediaItem;
  }

  MediaItem? get currentMediaItem => mediaItemAt(index);

  EngineMedia? get currentMedia {
    if (index < 0 || index >= medias.length) return null;
    return medias[index];
  }
}

/// Synchronous engine snapshot used by controllers instead of reading
/// just_audio player state directly.
class PlaybackEngineState {
  final EnginePlaylist playlist;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final bool playing;
  final bool buffering;
  final bool completed;
  final double rate;
  final double volume;

  const PlaybackEngineState({
    this.playlist = const EnginePlaylist(),
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.rate = 1.0,
    this.volume = 1.0,
  });
}

/// Vendor-neutral playback port. Controllers talk only to this type.
///
/// Volume is always 0..1. [move] uses destination index in the current list
/// (0..length-1), not an insert-before index.
abstract class PlaybackEngine {
  PlaybackEngineState get state;

  Stream<bool> get playingStream;
  Stream<bool> get bufferingStream;
  Stream<bool> get completedStream;
  Stream<EnginePlaylist> get playlistStream;
  Stream<Duration> get durationStream;
  Stream<Duration> get positionStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<bool> get shuffleStream;
  Stream<EngineRepeatMode> get repeatModeStream;
  Stream<String> get errorStream;

  Future<void> open(
    List<EngineMedia> medias, {
    int index = 0,
    bool play = true,
    Duration position = Duration.zero,
  });

  Future<void> add(EngineMedia media);

  Future<void> remove(int index);

  /// Replaces the source at [index] without changing playlist length or order.
  ///
  /// Prefer this over remove → add → move: just_audio's concatenating `move`
  /// hits an ExoPlayer `IllegalArgumentException` on Android.
  Future<void> replace(int index, EngineMedia media);

  /// Moves the item at [from] so it occupies [to] in the resulting list.
  Future<void> move(int from, int to);

  Future<void> jump(int index);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration position);

  Future<void> setVolume(double volume);

  Future<void> setShuffle(bool enabled);

  Future<void> setRepeatMode(EngineRepeatMode mode);

  Future<void> dispose();
}

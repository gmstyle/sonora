import 'dart:async';

import 'package:sonora/presentation/features/player/playback_engine.dart';

/// In-memory [PlaybackEngine] for unit tests. Does not touch libmpv / ExoPlayer.
class FakePlaybackEngine implements PlaybackEngine {
  EnginePlaylist playlist;
  Duration position;
  Duration duration;
  Duration bufferedPosition;
  bool playing;
  bool buffering;
  bool completed;
  double rate;
  double volume;

  final _playing = StreamController<bool>.broadcast();
  final _buffering = StreamController<bool>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _playlist = StreamController<EnginePlaylist>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _buffered = StreamController<Duration>.broadcast();
  final _shuffle = StreamController<bool>.broadcast();
  final _repeat = StreamController<EngineRepeatMode>.broadcast();
  final _error = StreamController<String>.broadcast();

  bool shuffleEnabled = false;
  EngineRepeatMode repeatMode = EngineRepeatMode.none;

  FakePlaybackEngine({
    EnginePlaylist? playlist,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.rate = 1.0,
    this.volume = 1.0,
  }) : playlist = playlist ?? const EnginePlaylist();

  void emitPlaylist() => _playlist.add(playlist);

  @override
  PlaybackEngineState get state => PlaybackEngineState(
    playlist: playlist,
    position: position,
    duration: duration,
    bufferedPosition: bufferedPosition,
    playing: playing,
    buffering: buffering,
    completed: completed,
    rate: rate,
    volume: volume,
  );

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Stream<bool> get bufferingStream => _buffering.stream;

  @override
  Stream<bool> get completedStream => _completed.stream;

  @override
  Stream<EnginePlaylist> get playlistStream => _playlist.stream;

  @override
  Stream<Duration> get durationStream => _duration.stream;

  @override
  Stream<Duration> get positionStream => _position.stream;

  @override
  Stream<Duration> get bufferedPositionStream => _buffered.stream;

  @override
  Stream<bool> get shuffleStream => _shuffle.stream;

  @override
  Stream<EngineRepeatMode> get repeatModeStream => _repeat.stream;

  @override
  Stream<String> get errorStream => _error.stream;

  @override
  Future<void> open(
    List<EngineMedia> medias, {
    int index = 0,
    bool play = true,
    Duration position = Duration.zero,
  }) async {
    playlist = EnginePlaylist(index: index, medias: List.of(medias));
    playing = play && medias.isNotEmpty;
    this.position = position;
    emitPlaylist();
  }

  @override
  Future<void> add(EngineMedia media) async {
    playlist = EnginePlaylist(
      index: playlist.index,
      medias: [...playlist.medias, media],
    );
    emitPlaylist();
  }

  @override
  Future<void> remove(int index) async {
    final medias = List<EngineMedia>.from(playlist.medias)..removeAt(index);
    var newIndex = playlist.index;
    if (index < newIndex) newIndex--;
    if (newIndex >= medias.length) newIndex = medias.length - 1;
    if (newIndex < 0) newIndex = 0;
    playlist = EnginePlaylist(index: newIndex, medias: medias);
    emitPlaylist();
  }

  @override
  Future<void> replace(int index, EngineMedia media) async {
    if (index < 0 || index >= playlist.medias.length) return;
    final medias = List<EngineMedia>.from(playlist.medias);
    medias[index] = media;
    playlist = EnginePlaylist(index: playlist.index, medias: medias);
    emitPlaylist();
  }

  @override
  Future<void> move(int from, int to) async {
    if (from == to) return;
    final medias = List<EngineMedia>.from(playlist.medias);
    final item = medias.removeAt(from);
    medias.insert(to, item);
    playlist = EnginePlaylist(index: playlist.index, medias: medias);
    emitPlaylist();
  }

  @override
  Future<void> jump(int index) async {
    playlist = EnginePlaylist(index: index, medias: playlist.medias);
    emitPlaylist();
  }

  @override
  Future<void> play() async {
    playing = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    playing = false;
    _playing.add(false);
  }

  @override
  Future<void> stop() async {
    playing = false;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    this.position = position;
    _position.add(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    this.volume = volume;
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    shuffleEnabled = enabled;
    _shuffle.add(enabled);
  }

  @override
  Future<void> setRepeatMode(EngineRepeatMode mode) async {
    repeatMode = mode;
    _repeat.add(mode);
  }

  @override
  Future<void> dispose() async {
    await _playing.close();
    await _buffering.close();
    await _completed.close();
    await _playlist.close();
    await _duration.close();
    await _position.close();
    await _buffered.close();
    await _shuffle.close();
    await _repeat.close();
    await _error.close();
  }
}

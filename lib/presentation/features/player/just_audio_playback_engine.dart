import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

import 'playback_engine.dart';

/// [PlaybackEngine] backed by just_audio (ExoPlayer on Android, libmpv via
/// `just_audio_media_kit` on Linux).
///
/// Shuffle is **not** applied at the engine: [SkipNavigator] owns skip order,
/// and `just_audio_media_kit` ignores `shuffleOrder` anyway.
class JustAudioPlaybackEngine implements PlaybackEngine {
  final AudioPlayer _player;
  final AndroidEqualizer? androidEqualizer;

  final _shuffleOut = StreamController<bool>.broadcast();
  final _repeatOut = StreamController<EngineRepeatMode>.broadcast();

  JustAudioPlaybackEngine(this._player, {this.androidEqualizer});

  factory JustAudioPlaybackEngine.create() {
    AndroidEqualizer? eq;
    AudioPipeline? pipeline;
    if (Platform.isAndroid) {
      eq = AndroidEqualizer();
      pipeline = AudioPipeline(androidAudioEffects: [eq]);
    }
    final player = AudioPlayer(
      handleInterruptions: false,
      handleAudioSessionActivation: false,
      androidApplyAudioAttributes: false,
      maxSkipsOnError: 0,
      useLazyPreparation: true,
      audioPipeline: pipeline,
    );
    return JustAudioPlaybackEngine(player, androidEqualizer: eq);
  }

  static AudioSource toSource(EngineMedia media) {
    if (isPlaceholderAudioUri(media.uri)) {
      return SilenceAudioSource(
        duration: const Duration(seconds: 1),
        tag: media,
      );
    }
    return AudioSource.uri(Uri.parse(media.uri), tag: media);
  }

  static EngineMedia fromSource(IndexedAudioSource source) {
    final tag = source.tag;
    if (tag is EngineMedia) return tag;
    final uri = source is UriAudioSource ? source.uri.toString() : '';
    return EngineMedia(uri: uri);
  }

  static LoopMode repeatToJa(EngineRepeatMode mode) {
    return switch (mode) {
      EngineRepeatMode.none => LoopMode.off,
      EngineRepeatMode.one => LoopMode.one,
      EngineRepeatMode.all => LoopMode.all,
    };
  }

  static EngineRepeatMode repeatFromJa(LoopMode mode) {
    return switch (mode) {
      LoopMode.off => EngineRepeatMode.none,
      LoopMode.one => EngineRepeatMode.one,
      LoopMode.all => EngineRepeatMode.all,
    };
  }

  EnginePlaylist _snapshotPlaylist() {
    return EnginePlaylist(
      index: _player.currentIndex ?? 0,
      medias: _player.sequence.map(fromSource).toList(),
    );
  }

  bool _isBuffering(ProcessingState state) =>
      state == ProcessingState.loading || state == ProcessingState.buffering;

  @override
  PlaybackEngineState get state {
    final processing = _player.processingState;
    return PlaybackEngineState(
      playlist: _snapshotPlaylist(),
      position: _player.position,
      duration: _player.duration ?? Duration.zero,
      bufferedPosition: _player.bufferedPosition,
      playing: _player.playing,
      buffering: _isBuffering(processing),
      completed: processing == ProcessingState.completed,
      rate: _player.speed,
      volume: _player.volume,
    );
  }

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<bool> get bufferingStream =>
      _player.processingStateStream.map(_isBuffering);

  @override
  Stream<bool> get completedStream =>
      _player.processingStateStream.map((s) => s == ProcessingState.completed);

  @override
  Stream<EnginePlaylist> get playlistStream => _player.sequenceStateStream.map(
    (s) => EnginePlaylist(
      index: s.currentIndex ?? 0,
      medias: s.sequence.map(fromSource).toList(),
    ),
  );

  @override
  Stream<Duration> get durationStream =>
      _player.durationStream.map((d) => d ?? Duration.zero);

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  @override
  Stream<bool> get shuffleStream => _shuffleOut.stream;

  @override
  Stream<EngineRepeatMode> get repeatModeStream => _repeatOut.stream;

  @override
  Stream<String> get errorStream =>
      _player.errorStream.map((e) => e.message ?? 'Player error ${e.code}');

  @override
  Future<void> open(
    List<EngineMedia> medias, {
    int index = 0,
    bool play = true,
  }) async {
    if (medias.isEmpty) {
      await _player.stop();
      await _player.clearAudioSources();
      return;
    }
    final clamped = index.clamp(0, medias.length - 1);
    await _player.setAudioSources(
      medias.map(toSource).toList(),
      initialIndex: clamped,
      preload: true,
    );
    if (play) {
      await _player.play();
    } else {
      await _player.pause();
    }
  }

  @override
  Future<void> add(EngineMedia media) =>
      _player.addAudioSource(toSource(media));

  @override
  Future<void> remove(int index) => _player.removeAudioSourceAt(index);

  @override
  Future<void> replace(int index, EngineMedia media) async {
    final len = _player.audioSources.length;
    if (index < 0 || index >= len) return;
    await _player.removeAudioSourceAt(index);
    await _player.insertAudioSource(index, toSource(media));
  }

  @override
  Future<void> move(int from, int to) {
    if (from == to) return Future.value();
    return _player.moveAudioSource(from, to);
  }

  @override
  Future<void> jump(int index) => _player.seek(Duration.zero, index: index);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume(volume.clamp(0.0, 1.0));

  @override
  Future<void> setShuffle(bool enabled) async {
    if (!_shuffleOut.isClosed) _shuffleOut.add(enabled);
  }

  @override
  Future<void> setRepeatMode(EngineRepeatMode mode) async {
    await _player.setLoopMode(repeatToJa(mode));
    if (!_repeatOut.isClosed) _repeatOut.add(mode);
  }

  @override
  Future<void> attachExternalAudio(String? uri) async {
    // Video-only cache pairs are no longer used; just_audio has no sidecar track.
  }

  @override
  Future<void> dispose() async {
    await _shuffleOut.close();
    await _repeatOut.close();
    await _player.dispose();
  }
}

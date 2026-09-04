import 'package:audio_service/audio_service.dart';
import 'package:media_kit/media_kit.dart';

import 'playback_engine.dart';

/// [PlaybackEngine] backed by a media_kit [Player].
///
/// Unused while [JustAudioPlaybackEngine] is the production engine. Kept as a
/// Linux fallback if `just_audio_media_kit` playlist/seek/webm playback fails.
class MediaKitPlaybackEngine implements PlaybackEngine {
  final Player _player;

  MediaKitPlaybackEngine(this._player);

  factory MediaKitPlaybackEngine.create() {
    return MediaKitPlaybackEngine(
      Player(configuration: const PlayerConfiguration(pitch: true)),
    );
  }

  /// Underlying media_kit player. Used by equalizer and engine configurator.
  Player get nativePlayer => _player;

  static Media toMk(EngineMedia media) {
    final extras = <String, dynamic>{
      if (media.mediaItem != null) 'mediaItem': media.mediaItem,
      if (media.externalAudioUri != null && media.externalAudioUri!.isNotEmpty)
        kExternalAudioUriExtraKey: media.externalAudioUri,
    };
    return Media(media.uri, extras: extras.isEmpty ? null : extras);
  }

  static EngineMedia fromMk(Media media) {
    return EngineMedia(
      uri: media.uri,
      mediaItem: media.extras?['mediaItem'] as MediaItem?,
      externalAudioUri: media.extras?[kExternalAudioUriExtraKey] as String?,
    );
  }

  static EnginePlaylist playlistFromMk(Playlist playlist) {
    return EnginePlaylist(
      index: playlist.index,
      medias: playlist.medias.map(fromMk).toList(),
    );
  }

  static EngineRepeatMode repeatFromMk(PlaylistMode mode) {
    return switch (mode) {
      PlaylistMode.none => EngineRepeatMode.none,
      PlaylistMode.single => EngineRepeatMode.one,
      PlaylistMode.loop => EngineRepeatMode.all,
    };
  }

  static PlaylistMode repeatToMk(EngineRepeatMode mode) {
    return switch (mode) {
      EngineRepeatMode.none => PlaylistMode.none,
      EngineRepeatMode.one => PlaylistMode.single,
      EngineRepeatMode.all => PlaylistMode.loop,
    };
  }

  @override
  PlaybackEngineState get state {
    final s = _player.state;
    return PlaybackEngineState(
      playlist: playlistFromMk(s.playlist),
      position: s.position,
      duration: s.duration,
      bufferedPosition: s.buffer,
      playing: s.playing,
      buffering: s.buffering,
      completed: s.completed,
      rate: s.rate,
      volume: (s.volume / 100.0).clamp(0.0, 1.0),
    );
  }

  @override
  Stream<bool> get playingStream => _player.stream.playing;

  @override
  Stream<bool> get bufferingStream => _player.stream.buffering;

  @override
  Stream<bool> get completedStream => _player.stream.completed;

  @override
  Stream<EnginePlaylist> get playlistStream =>
      _player.stream.playlist.map(playlistFromMk);

  @override
  Stream<Duration> get durationStream => _player.stream.duration;

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Stream<Duration> get bufferedPositionStream => _player.stream.buffer;

  @override
  Stream<bool> get shuffleStream => _player.stream.shuffle;

  @override
  Stream<EngineRepeatMode> get repeatModeStream =>
      _player.stream.playlistMode.map(repeatFromMk);

  @override
  Stream<String> get errorStream => _player.stream.error;

  @override
  Future<void> open(
    List<EngineMedia> medias, {
    int index = 0,
    bool play = true,
  }) {
    return _player.open(
      Playlist(medias.map(toMk).toList(), index: index),
      play: play,
    );
  }

  @override
  Future<void> add(EngineMedia media) => _player.add(toMk(media));

  @override
  Future<void> remove(int index) => _player.remove(index);

  @override
  Future<void> replace(int index, EngineMedia media) async {
    final len = _player.state.playlist.medias.length;
    if (index < 0 || index >= len) return;
    await _player.remove(index);
    await _player.add(toMk(media));
    final last = _player.state.playlist.medias.length - 1;
    if (last != index) {
      await move(last, index);
    }
  }

  @override
  Future<void> move(int from, int to) {
    if (from == to) return Future.value();
    final mkTo = from < to ? to + 1 : to;
    return _player.move(from, mkTo);
  }

  @override
  Future<void> jump(int index) => _player.jump(index);

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
      _player.setVolume((volume.clamp(0.0, 1.0) * 100.0));

  @override
  Future<void> setShuffle(bool enabled) => _player.setShuffle(enabled);

  @override
  Future<void> setRepeatMode(EngineRepeatMode mode) =>
      _player.setPlaylistMode(repeatToMk(mode));

  @override
  Future<void> attachExternalAudio(String? uri) {
    if (uri != null && uri.isNotEmpty) {
      return _player.setAudioTrack(AudioTrack.uri(uri));
    }
    return _player.setAudioTrack(AudioTrack.auto());
  }

  @override
  Future<void> dispose() => _player.dispose();
}

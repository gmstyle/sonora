import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sonora/data/datasources/remote/stream_datasource.dart';
import 'package:sonora/domain/models/media_quality.dart';
import 'package:sonora/domain/models/queue_track.dart';
import 'package:sonora/presentation/features/player/adaptive_audio_binder.dart';

class _RecordingPlayer extends Fake implements Player {
  final List<AudioTrack> tracks = [];

  @override
  Future<void> setAudioTrack(AudioTrack track) async {
    tracks.add(track);
  }
}

class _FakeStreamDatasource extends StreamDatasource {
  PlaybackUrlPlan plan;

  _FakeStreamDatasource(this.plan);

  @override
  Future<PlaybackUrlPlan> ensurePlaybackSelection(
    String videoId, {
    MediaQuality? audioQuality,
    MediaQuality? videoQuality,
    bool preferVideo = false,
    int attempt = 1,
  }) async => plan;
}

Playlist _playlist({
  required bool adaptiveCandidate,
  String? audioProxyUrl,
  String videoId = 'vid1',
}) {
  final item =
      QueueTrack(
        videoId: videoId,
        title: 'T',
        artist: 'A',
        isVideo: true,
      ).toFreshMediaItem();

  return Playlist([
    Media(
      'http://127.0.0.1/stream?videoId=$videoId&kind=video',
      extras: {
        'mediaItem': item,
        if (adaptiveCandidate) 'adaptiveCandidate': true,
        if (audioProxyUrl != null) 'audioProxyUrl': audioProxyUrl,
      },
    ),
  ]);
}

void main() {
  test('adaptive plan binds AudioTrack.uri', () async {
    final player = _RecordingPlayer();
    const audioUrl = 'http://127.0.0.1/stream?videoId=vid1&kind=audio';
    final binder = AdaptiveAudioBinder(
      player: player,
      streamDatasource: _FakeStreamDatasource(
        const PlaybackUrlPlan(
          primaryUrl: 'http://cdn/video.mp4',
          externalAudioUrl: 'http://cdn/audio.m4a',
        ),
      ),
      getStreamAudioQuality: () => MediaQuality.high,
      getStreamVideoQuality: () => MediaQuality.mid,
    );

    await binder.onPlaylistChanged(
      _playlist(adaptiveCandidate: true, audioProxyUrl: audioUrl),
    );

    expect(player.tracks, hasLength(1));
    expect(player.tracks.single.uri, isTrue);
    expect(player.tracks.single.id, audioUrl);
    expect(player.tracks.single.title, 'sonora-yt-audio');
  });

  test('does not rebind the same adaptive URI twice', () async {
    final player = _RecordingPlayer();
    const audioUrl = 'http://127.0.0.1/stream?videoId=vid1&kind=audio';
    final binder = AdaptiveAudioBinder(
      player: player,
      streamDatasource: _FakeStreamDatasource(
        const PlaybackUrlPlan(
          primaryUrl: 'http://cdn/video.mp4',
          externalAudioUrl: 'http://cdn/audio.m4a',
        ),
      ),
      getStreamAudioQuality: () => MediaQuality.high,
      getStreamVideoQuality: () => MediaQuality.mid,
    );
    final playlist = _playlist(
      adaptiveCandidate: true,
      audioProxyUrl: audioUrl,
    );

    await binder.onPlaylistChanged(playlist);
    await binder.onPlaylistChanged(playlist);

    expect(player.tracks, hasLength(1));
  });

  test('muxed-only plan clears to AudioTrack.auto', () async {
    final player = _RecordingPlayer();
    final binder = AdaptiveAudioBinder(
      player: player,
      streamDatasource: _FakeStreamDatasource(
        const PlaybackUrlPlan(primaryUrl: 'http://cdn/muxed.mp4'),
      ),
      getStreamAudioQuality: () => MediaQuality.high,
      getStreamVideoQuality: () => MediaQuality.high,
    );

    await binder.onPlaylistChanged(
      _playlist(
        adaptiveCandidate: true,
        audioProxyUrl: 'http://127.0.0.1/stream?kind=audio',
      ),
    );

    expect(player.tracks, hasLength(1));
    expect(player.tracks.single.id, 'auto');
    expect(player.tracks.single.uri, isFalse);
  });

  test('non-candidate clears to AudioTrack.auto', () async {
    final player = _RecordingPlayer();
    final binder = AdaptiveAudioBinder(
      player: player,
      streamDatasource: _FakeStreamDatasource(
        const PlaybackUrlPlan(
          primaryUrl: 'http://cdn/video.mp4',
          externalAudioUrl: 'http://cdn/audio.m4a',
        ),
      ),
      getStreamAudioQuality: () => MediaQuality.high,
      getStreamVideoQuality: () => MediaQuality.high,
    );

    await binder.onPlaylistChanged(_playlist(adaptiveCandidate: false));

    expect(player.tracks, hasLength(1));
    expect(player.tracks.single.id, 'auto');
  });
}

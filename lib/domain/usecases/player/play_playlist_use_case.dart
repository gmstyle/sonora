import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import '../../models/queue_track.dart';
import '../../repositories/music_repository.dart';

/// Builds a [List<MediaItem>] from a playlist's video list.
///
/// Only resolves the stream URL for the track at [playIndex] (default 0),
/// which will play first. All other tracks are added as pending
/// ([needsUrl]) — the player resolves their URLs lazily when they are
/// about to play.
///
/// Pass [playIndex] = -1 to skip URL resolution entirely (e.g. when
/// adding to queue without immediate playback).
///
/// Pass a pre-shuffled list when shuffle play is desired.
class PlayPlaylistUseCase {
  final MusicRepository _repo;

  PlayPlaylistUseCase(this._repo);

  Future<List<MediaItem>> execute(
    List<VideoDetailed> videos, {
    int playIndex = 0,
  }) async {
    if (videos.isEmpty) return [];

    String? firstUrl;
    if (playIndex >= 0 && playIndex < videos.length) {
      try {
        firstUrl = await _repo.getStreamUrl(videos[playIndex].videoId);
      } catch (_) {}
    }

    return [
      for (int i = 0; i < videos.length; i++)
        i == playIndex && firstUrl != null
            ? _toMediaItem(videos[i], firstUrl)
            : _toPendingMediaItem(videos[i]),
    ];
  }

  MediaItem _toMediaItem(VideoDetailed v, String url) {
    final track = QueueTrack(
      videoId: v.videoId,
      url: url,
      isVideo: true,
      isExplicit: v.isExplicit,
      artistId: v.artist.artistId,
      title: v.name,
      artist: v.artist.name,
      duration: Duration(seconds: v.duration ?? 0),
      artUri: v.thumbnails.isNotEmpty ? Uri.parse(v.thumbnails.last.url) : null,
    );
    return track.toFreshMediaItem();
  }

  MediaItem _toPendingMediaItem(VideoDetailed v) {
    final track = QueueTrack(
      videoId: v.videoId,
      needsUrl: true,
      isVideo: true,
      isExplicit: v.isExplicit,
      artistId: v.artist.artistId,
      title: v.name,
      artist: v.artist.name,
      duration: Duration(seconds: v.duration ?? 0),
      artUri: v.thumbnails.isNotEmpty ? Uri.parse(v.thumbnails.last.url) : null,
    );
    return track.toFreshMediaItem();
  }
}

import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import '../../models/queue_track.dart';
import '../../repositories/music_repository.dart';

/// Builds a [List<MediaItem>] from an album's song list.
///
/// Only resolves the stream URL for the track at [playIndex] (default 0),
/// which will play first. All other tracks are added as pending
/// ([needsUrl]) — the player resolves their URLs lazily when they are
/// about to play.
///
/// Pass [playIndex] = -1 to skip URL resolution entirely (e.g. when
/// adding to queue without immediate playback).
///
/// Pass a pre-shuffled list when shuffle play is desired — the use case
/// does not shuffle internally.
class PlayAlbumUseCase {
  final MusicRepository _repo;

  PlayAlbumUseCase(this._repo);

  Future<List<MediaItem>> execute(
    List<SongDetailed> songs, {
    int playIndex = 0,
  }) async {
    if (songs.isEmpty) return [];

    String? firstUrl;
    if (playIndex >= 0 && playIndex < songs.length) {
      try {
        firstUrl = await _repo.getStreamUrl(songs[playIndex].videoId);
      } catch (_) {}
    }

    return [
      for (int i = 0; i < songs.length; i++)
        i == playIndex && firstUrl != null
            ? _toMediaItem(songs[i], firstUrl)
            : _toPendingMediaItem(songs[i]),
    ];
  }

  MediaItem _toMediaItem(SongDetailed s, String url) {
    final track = QueueTrack(
      videoId: s.videoId,
      url: url,
      isVideo: false,
      isExplicit: s.isExplicit,
      artistId: s.artist.artistId,
      albumId: s.album?.albumId,
      title: s.name,
      artist: s.artist.name,
      album: s.album?.name,
      duration: Duration(seconds: s.duration ?? 0),
      artUri: s.thumbnails.isNotEmpty ? Uri.parse(s.thumbnails.last.url) : null,
    );
    return track.toFreshMediaItem();
  }

  MediaItem _toPendingMediaItem(SongDetailed s) {
    final track = QueueTrack(
      videoId: s.videoId,
      needsUrl: true,
      isVideo: false,
      isExplicit: s.isExplicit,
      artistId: s.artist.artistId,
      albumId: s.album?.albumId,
      title: s.name,
      artist: s.artist.name,
      album: s.album?.name,
      duration: Duration(seconds: s.duration ?? 0),
      artUri: s.thumbnails.isNotEmpty ? Uri.parse(s.thumbnails.last.url) : null,
    );
    return track.toFreshMediaItem();
  }
}

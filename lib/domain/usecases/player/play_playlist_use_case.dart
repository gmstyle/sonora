import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import '../../models/queue_track.dart';
import '../../../core/utils/artists_utils.dart';
import '../../../core/utils/playable_tracks.dart';
import 'play_video_id_use_case.dart';

/// Builds a [List<MediaItem>] from a playlist's video list.
///
/// Drops tracks with [VideoDetailed.isPlayable] == false. Only resolves the URL
/// for the track at [playIndex] (mapped onto the playable subset), which will
/// play first — via [PlayVideoIdUseCase.resolveUrl] so a completed download or
/// audio cache hit is used instead of a live stream. All other tracks are
/// added as pending ([needsUrl]) — the player resolves their URLs lazily when
/// they are about to play.
///
/// Pass [playIndex] = -1 to skip URL resolution entirely (e.g. when
/// adding to queue without immediate playback).
///
/// Pass a pre-shuffled list when shuffle play is desired.
class PlayPlaylistUseCase {
  final PlayVideoIdUseCase _playVideoId;

  PlayPlaylistUseCase(this._playVideoId);

  Future<List<MediaItem>> execute(
    List<VideoDetailed> videos, {
    int playIndex = 0,
  }) async {
    final playable = playableVideos(videos);
    if (playable.isEmpty) return [];

    final leadIndex =
        playIndex < 0
            ? -1
            : playableLeadIndex(videos, playIndex, playable: playable);

    String? firstUrl;
    if (leadIndex >= 0 && leadIndex < playable.length) {
      firstUrl = await _playVideoId.resolveUrl(playable[leadIndex].videoId);
    }

    return [
      for (int i = 0; i < playable.length; i++)
        i == leadIndex && firstUrl != null
            ? _toMediaItem(playable[i], firstUrl)
            : _toPendingMediaItem(playable[i]),
    ];
  }

  MediaItem _toMediaItem(VideoDetailed v, String url) {
    final track = QueueTrack(
      videoId: v.videoId,
      url: url,
      isVideo: true,
      isExplicit: v.isExplicit,
      artistId: primaryArtistId(v.artists),
      artistsJson: encodeArtistsJson(v.artists),
      title: v.name,
      artist: displayArtists(v.artists),
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
      artistId: primaryArtistId(v.artists),
      artistsJson: encodeArtistsJson(v.artists),
      title: v.name,
      artist: displayArtists(v.artists),
      duration: Duration(seconds: v.duration ?? 0),
      artUri: v.thumbnails.isNotEmpty ? Uri.parse(v.thumbnails.last.url) : null,
    );
    return track.toFreshMediaItem();
  }
}

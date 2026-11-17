import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../../models/queue_track.dart';
import '../../../core/utils/artists_utils.dart';
import '../../../core/utils/playable_tracks.dart';
import 'play_video_id_use_case.dart';
import 'resolve_lead_track.dart';

/// Builds a [List<MediaItem>] from an album's song list.
///
/// Drops tracks with [SongDetailed.isPlayable] == false. Only resolves the URL
/// for the track at [playIndex] (mapped onto the playable subset), which will
/// play first — via [PlayVideoIdUseCase.resolveUrl] so a completed download or
/// audio cache hit is used instead of a live stream. All other tracks are
/// added as pending ([needsUrl]) — the player resolves their URLs lazily when
/// they are about to play.
///
/// Pass [playIndex] = -1 to skip URL resolution entirely (e.g. when
/// adding to queue without immediate playback).
///
/// Pass a pre-shuffled list when shuffle play is desired — the use case
/// does not shuffle internally.
class PlayAlbumUseCase {
  final PlayVideoIdUseCase _playVideoId;

  PlayAlbumUseCase(this._playVideoId);

  Future<List<MediaItem>> execute(
    List<SongDetailed> songs, {
    int playIndex = 0,
    void Function(int index)? onResolvedLeadIndex,
  }) {
    return buildPlayableQueue(
      songs,
      playable: playableSongs(songs),
      playIndex: playIndex,
      videoIdOf: (s) => s.videoId,
      resolveUrl: _playVideoId.resolveUrl,
      toMediaItem: (s, url) => _toMediaItem(s, url: url),
      onResolvedLeadIndex: onResolvedLeadIndex,
    );
  }

  MediaItem _toMediaItem(SongDetailed s, {String? url}) {
    final track = QueueTrack(
      videoId: s.videoId,
      url: url,
      needsUrl: url == null,
      isVideo: false,
      isExplicit: s.isExplicit,
      artistId: primaryArtistId(s.artists),
      albumId: s.album?.albumId,
      artistsJson: encodeArtistsJson(s.artists),
      title: s.name,
      artist: displayArtists(s.artists),
      album: s.album?.name,
      duration: Duration(seconds: s.duration ?? 0),
      artUri: s.thumbnails.isNotEmpty ? Uri.parse(s.thumbnails.last.url) : null,
    );
    return track.toFreshMediaItem();
  }
}

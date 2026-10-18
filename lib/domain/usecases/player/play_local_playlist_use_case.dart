import 'package:audio_service/audio_service.dart';

import '../../models/library_models.dart';
import '../../models/queue_track.dart';
import '../../repositories/library_repository.dart';
import 'play_video_id_use_case.dart';

/// Builds a [List<MediaItem>] from a local custom playlist's entries.
///
/// Same contract as [PlayPlaylistUseCase] / [PlaySmartMixUseCase]: only the
/// lead at [playIndex] is resolved via [PlayVideoIdUseCase.resolveUrl]; other
/// rows stay [needsUrl] for lazy resolve in the playback stack. Pass
/// [playIndex] = -1 to skip URL resolution (add to queue).
///
/// Metadata prefers liked-song rows when present, then stored entry fields.
class PlayLocalPlaylistUseCase {
  PlayLocalPlaylistUseCase(this._playVideoId, this._library);

  final PlayVideoIdUseCase _playVideoId;
  final LibraryRepository _library;

  Future<List<MediaItem>> execute(
    List<PlaylistEntryModel> entries, {
    int playIndex = 0,
  }) async {
    if (entries.isEmpty) return [];

    String? firstUrl;
    if (playIndex >= 0 && playIndex < entries.length) {
      // Do not swallow failures: playNow rejects a placeholder lead track.
      firstUrl = await _playVideoId.resolveUrl(entries[playIndex].videoId);
    }

    final items = <MediaItem>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final liked = await _library.getLikedSong(entry.videoId);
      final isLead = playIndex >= 0 && i == playIndex;
      items.add(
        _toMediaItem(entry, liked: liked, url: isLead ? firstUrl : null),
      );
    }
    return items;
  }

  MediaItem _toMediaItem(
    PlaylistEntryModel entry, {
    LikedSongModel? liked,
    String? url,
  }) {
    final durationSec = liked?.duration ?? entry.duration;
    final thumbnailUrl = liked?.thumbnailUrl ?? entry.thumbnailUrl;
    return QueueTrack(
      videoId: entry.videoId,
      url: url,
      needsUrl: url == null,
      isVideo: liked?.isVideo ?? entry.isVideo,
      isExplicit: liked?.isExplicit ?? entry.isExplicit,
      artistId: liked?.artistId,
      artistsJson: liked?.artistsJson ?? entry.artistsJson,
      title: liked?.title ?? entry.title ?? entry.videoId,
      artist: liked?.artist ?? entry.artist ?? '',
      duration: durationSec != null ? Duration(seconds: durationSec) : null,
      artUri: thumbnailUrl != null ? Uri.tryParse(thumbnailUrl) : null,
    ).toFreshMediaItem();
  }
}

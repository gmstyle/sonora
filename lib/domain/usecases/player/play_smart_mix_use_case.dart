import 'package:audio_service/audio_service.dart';
import '../../../domain/models/library_models.dart';
import '../../models/queue_track.dart';
import '../../repositories/music_repository.dart';

class PlaySmartMixUseCase {
  final MusicRepository _repo;

  PlaySmartMixUseCase(this._repo);

  Future<List<MediaItem>> execute({
    required List<dynamic> songs,
    int playIndex = 0,
  }) async {
    if (songs.isEmpty) return [];

    String? startUrl;
    if (playIndex >= 0 && playIndex < songs.length) {
      try {
        final videoId = _getVideoId(songs[playIndex]);
        startUrl = await _repo.getStreamUrl(videoId);
      } catch (_) {}
    }

    return [
      for (int i = 0; i < songs.length; i++)
        _toMediaItem(songs[i], i == playIndex ? startUrl : null),
    ];
  }

  String _getVideoId(dynamic song) {
    if (song is HistoryModel) return song.videoId;
    if (song is LikedSongModel) return song.videoId;
    return song.videoId as String;
  }

  MediaItem _toMediaItem(dynamic s, String? url) {
    final isExplicit =
        s is HistoryModel
            ? s.isExplicit
            : s is LikedSongModel
            ? s.isExplicit
            : s is DownloadModel
            ? s.isExplicit
            : false;

    final track = QueueTrack(
      videoId: s.videoId,
      url: url,
      needsUrl: url == null,
      isVideo: s.isVideo,
      isExplicit: isExplicit,
      artistId: s is LikedSongModel ? s.artistId : null,
      albumId: s is LikedSongModel ? s.albumId : null,
      title: s.title,
      artist: s.artist,
      duration: s.duration != null ? Duration(seconds: s.duration!) : null,
      artUri: s.thumbnailUrl != null ? Uri.tryParse(s.thumbnailUrl!) : null,
    );
    return track.toFreshMediaItem();
  }
}

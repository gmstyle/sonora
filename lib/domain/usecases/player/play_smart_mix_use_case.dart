import 'package:audio_service/audio_service.dart';
import '../../../domain/models/library_models.dart';
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
    final extras = <String, dynamic>{
      if (url != null) 'url': url,
      if (url == null) 'needsUrl': true,
      'videoId': s.videoId,
      'isVideo': s.isVideo,
      'isExplicit':
          s is HistoryModel
              ? s.isExplicit
              : s is LikedSongModel
              ? s.isExplicit
              : s is DownloadModel
              ? s.isExplicit
              : false,
    };
    if (s is LikedSongModel) {
      if (s.artistId != null) extras['artistId'] = s.artistId;
      if (s.albumId != null) extras['albumId'] = s.albumId;
    }

    return MediaItem(
      id: s.videoId,
      title: s.title,
      artist: s.artist,
      duration: s.duration != null ? Duration(seconds: s.duration!) : null,
      artUri: s.thumbnailUrl != null ? Uri.tryParse(s.thumbnailUrl!) : null,
      extras: extras,
    );
  }
}

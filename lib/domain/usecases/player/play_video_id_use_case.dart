import 'package:audio_service/audio_service.dart';
import '../../repositories/music_repository.dart';

/// Resolves a [videoId] to a fully populated [MediaItem] ready for playback.
///
/// Tries [MusicRepository.getSong] first; falls back to [MusicRepository.getVideo]
/// for music videos. Always resolves the stream URL before returning.
class PlayVideoIdUseCase {
  final MusicRepository _repo;

  PlayVideoIdUseCase(this._repo);

  Future<MediaItem> execute(String videoId) async {
    String title, artist, thumbnailUrl;
    int durationSec;
    bool isVideo;

    try {
      final song = await _repo.getSong(videoId);
      title = song.name;
      artist = song.artist.name;
      durationSec = song.duration;
      thumbnailUrl = song.thumbnails.isNotEmpty ? song.thumbnails.last.url : '';
      isVideo = false;
    } catch (_) {
      final video = await _repo.getVideo(videoId);
      title = video.name;
      artist = video.artist.name;
      durationSec = video.duration;
      thumbnailUrl =
          video.thumbnails.isNotEmpty ? video.thumbnails.last.url : '';
      isVideo = true;
    }

    final streamUrl = await _repo.getStreamUrl(videoId);
    return MediaItem(
      id: videoId,
      title: title,
      artist: artist,
      duration: Duration(seconds: durationSec),
      artUri: thumbnailUrl.isNotEmpty ? Uri.parse(thumbnailUrl) : null,
      extras: {'url': streamUrl, 'videoId': videoId, 'isVideo': isVideo},
    );
  }

  /// Resolves only the audio stream URL for [videoId].
  /// Used when metadata (title, artist, etc.) is already available from the UI.
  Future<String> resolveStreamUrl(String videoId) async {
    return _repo.getStreamUrl(videoId);
  }
}

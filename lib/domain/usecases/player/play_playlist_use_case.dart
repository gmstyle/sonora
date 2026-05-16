import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import '../../repositories/music_repository.dart';

/// Builds a [List<MediaItem>] from a playlist's video list, resolving stream
/// URLs for all tracks via [MusicRepository.getStreamUrl].
///
/// Pass a pre-shuffled list when shuffle play is desired.
class PlayPlaylistUseCase {
  final MusicRepository _repo;

  PlayPlaylistUseCase(this._repo);

  Future<List<MediaItem>> execute(List<VideoDetailed> videos) async {
    if (videos.isEmpty) return [];
    final urls = await Future.wait(
      videos.map((v) => _repo.getStreamUrl(v.videoId)),
    );
    return [
      for (int i = 0; i < videos.length; i++)
        MediaItem(
          id: videos[i].videoId,
          title: videos[i].name,
          artist: videos[i].artist.name,
          duration: Duration(seconds: videos[i].duration ?? 0),
          artUri:
              videos[i].thumbnails.isNotEmpty
                  ? Uri.parse(videos[i].thumbnails.last.url)
                  : null,
          extras: {
            'url': urls[i],
            'videoId': videos[i].videoId,
            'isVideo': true,
          },
        ),
    ];
  }
}

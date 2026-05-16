import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import '../../repositories/music_repository.dart';

/// Builds a [List<MediaItem>] from an album's song list, resolving stream URLs
/// for all tracks via [MusicRepository.getStreamUrl].
///
/// Pass a pre-shuffled list when shuffle play is desired — the use case
/// does not shuffle internally.
class PlayAlbumUseCase {
  final MusicRepository _repo;

  PlayAlbumUseCase(this._repo);

  Future<List<MediaItem>> execute(List<SongDetailed> songs) async {
    if (songs.isEmpty) return [];
    final urls = await Future.wait(
      songs.map((s) => _repo.getStreamUrl(s.videoId)),
    );
    return [
      for (int i = 0; i < songs.length; i++)
        MediaItem(
          id: songs[i].videoId,
          title: songs[i].name,
          artist: songs[i].artist.name,
          album: songs[i].album?.name,
          duration: Duration(seconds: songs[i].duration ?? 0),
          artUri:
              songs[i].thumbnails.isNotEmpty
                  ? Uri.parse(songs[i].thumbnails.last.url)
                  : null,
          extras: {
            'url': urls[i],
            'videoId': songs[i].videoId,
            'isVideo': false,
          },
        ),
    ];
  }
}

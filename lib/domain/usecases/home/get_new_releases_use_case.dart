import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import '../../repositories/music_repository.dart';

/// Fetches the global YouTube Music New Releases feed.
///
/// Returns albums/singles from [MusicRepository.getNewReleases]. Music videos
/// from the same response are available via [executeFull] when needed.
class GetNewReleasesUseCase {
  final MusicRepository _musicRepository;

  GetNewReleasesUseCase(this._musicRepository);

  Future<List<AlbumDetailed>> execute() async {
    final result = await _musicRepository.getNewReleases();
    return result.albums;
  }

  Future<NewReleasesResult> executeFull() => _musicRepository.getNewReleases();
}

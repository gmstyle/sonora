import '../../../domain/models/library_models.dart';
import '../../../domain/repositories/library_repository.dart';

/// Tracks whether the current track or episode is liked/saved and persists toggles.
///
/// Does not hold a back-reference to [SonoraAudioHandler]; [onLikeChanged]
/// is invoked whenever the optimistic like state changes so the caller can
/// rebuild media controls.
class LikeController {
  final LibraryRepository _libraryRepo;
  final void Function() _onLikeChanged;

  bool _isCurrentSongLiked = false;
  String? _currentVideoId;
  bool _currentIsEpisode = false;

  LikeController({required this._libraryRepo, required this._onLikeChanged});

  bool get isCurrentSongLiked => _isCurrentSongLiked;

  bool get isCurrentEpisode => _currentIsEpisode;

  Future<void> checkCurrentSongLiked(
    String videoId, {
    bool isEpisode = false,
  }) async {
    _currentVideoId = videoId;
    _currentIsEpisode = isEpisode;
    try {
      final isSaved = isEpisode
          ? (await _libraryRepo.getLikedEpisode(videoId)) != null
          : (await _libraryRepo.getLikedSong(videoId)) != null;
      if (_currentVideoId == videoId && _currentIsEpisode == isEpisode) {
        _isCurrentSongLiked = isSaved;
        _onLikeChanged();
      }
    } catch (_) {}
  }

  /// Flips the local like flag and notifies listeners (optimistic UI update).
  void toggleOptimistic() {
    _isCurrentSongLiked = !_isCurrentSongLiked;
    _onLikeChanged();
  }

  Future<void> toggleLikedSong(LikedSongModel song) =>
      _libraryRepo.toggleLikedSong(song);

  Future<void> toggleLikedEpisode(LikedEpisodeModel episode) =>
      _libraryRepo.toggleLikedEpisode(episode);
}

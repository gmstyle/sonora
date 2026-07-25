import '../../../domain/models/library_models.dart';
import '../../../domain/repositories/library_repository.dart';

/// Tracks whether the current song is liked and persists like toggles.
///
/// Does not hold a back-reference to [SonoraAudioHandler]; [onLikeChanged]
/// is invoked whenever the optimistic like state changes so the caller can
/// rebuild media controls.
class LikeController {
  final LibraryRepository _libraryRepo;
  final void Function() _onLikeChanged;

  bool _isCurrentSongLiked = false;
  String? _currentVideoId;

  LikeController({
    required LibraryRepository libraryRepo,
    required void Function() onLikeChanged,
  }) : _libraryRepo = libraryRepo,
       _onLikeChanged = onLikeChanged;

  bool get isCurrentSongLiked => _isCurrentSongLiked;

  Future<void> checkCurrentSongLiked(String videoId) async {
    _currentVideoId = videoId;
    try {
      final liked = await _libraryRepo.getLikedSong(videoId);
      if (_currentVideoId == videoId) {
        _isCurrentSongLiked = liked != null;
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
}

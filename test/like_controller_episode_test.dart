import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/domain/repositories/library_repository.dart';
import 'package:sonora/presentation/features/player/like_controller.dart';

class _FakeLibraryRepo extends Fake implements LibraryRepository {
  final Map<String, LikedSongModel> songs = {};
  final Map<String, LikedEpisodeModel> episodes = {};
  int songToggleCalls = 0;
  int episodeToggleCalls = 0;

  @override
  Future<LikedSongModel?> getLikedSong(String videoId) async => songs[videoId];

  @override
  Future<LikedEpisodeModel?> getLikedEpisode(String videoId) async =>
      episodes[videoId];

  @override
  Future<void> toggleLikedSong(LikedSongModel song) async {
    songToggleCalls++;
    if (songs.containsKey(song.videoId)) {
      songs.remove(song.videoId);
    } else {
      songs[song.videoId] = song;
    }
  }

  @override
  Future<void> toggleLikedEpisode(LikedEpisodeModel episode) async {
    episodeToggleCalls++;
    if (episodes.containsKey(episode.videoId)) {
      episodes.remove(episode.videoId);
    } else {
      episodes[episode.videoId] = episode;
    }
  }
}

void main() {
  late _FakeLibraryRepo repo;
  late LikeController controller;
  late int notifyCount;

  setUp(() {
    repo = _FakeLibraryRepo();
    notifyCount = 0;
    controller = LikeController(
      libraryRepo: repo,
      onLikeChanged: () => notifyCount++,
    );
  });

  test(
    'checkCurrentSongLiked routes episode checks to liked_episodes',
    () async {
      final now = DateTime(2026, 3, 1);
      repo.episodes['ep1'] = LikedEpisodeModel(
        videoId: 'ep1',
        name: 'Episode 1',
        addedAt: now,
      );

      await controller.checkCurrentSongLiked('ep1', isEpisode: true);
      expect(controller.isCurrentEpisode, isTrue);
      expect(controller.isCurrentSongLiked, isTrue);
      expect(notifyCount, 1);

      await controller.checkCurrentSongLiked('ep1', isEpisode: false);
      expect(controller.isCurrentEpisode, isFalse);
      expect(controller.isCurrentSongLiked, isFalse);
    },
  );

  test('toggleLikedEpisode persists via repository and toggleOptimistic flips state', () async {
    final episode = LikedEpisodeModel(
      videoId: 'ep2',
      name: 'Episode 2',
      podcastName: 'Podcast',
      addedAt: DateTime(2026, 3, 1),
    );

    await controller.toggleLikedEpisode(episode);
    expect(repo.episodeToggleCalls, 1);
    expect(repo.episodes.containsKey('ep2'), isTrue);

    controller.toggleOptimistic();
    expect(controller.isCurrentSongLiked, isTrue);
    expect(notifyCount, 1);
  });
}

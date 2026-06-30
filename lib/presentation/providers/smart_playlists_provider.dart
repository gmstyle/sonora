import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/library_models.dart';
import 'library_repository_provider.dart';

final mostPlayedSongsProvider = StreamProvider<List<HistoryModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchMostPlayedSongs();
});

final recentlyPlayedSongsProvider = StreamProvider<List<HistoryModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchRecentHistory();
});

final forgottenFavoritesProvider = StreamProvider<List<LikedSongModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.watchForgottenFavorites();
});

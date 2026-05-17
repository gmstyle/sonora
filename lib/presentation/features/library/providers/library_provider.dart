import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/library_repository_provider.dart';
import '../../../../domain/models/library_models.dart';

final likedSongsProvider = FutureProvider<List<LikedSongModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.getAllLikedSongs();
});

final followedArtistsProvider = FutureProvider<List<FollowedArtistModel>>((
  ref,
) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.getAllFollowedArtists();
});

final playlistsProvider = FutureProvider<List<LocalPlaylistModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.getAllPlaylists();
});

final playlistEntriesProvider =
    FutureProvider.family<List<PlaylistEntryModel>, int>((ref, playlistId) {
      final repo = ref.watch(libraryRepositoryProvider);
      return repo.getPlaylistEntries(playlistId);
    });

final libraryHistoryProvider = FutureProvider<List<HistoryModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.getRecentHistory(limit: 50);
});

final likedAlbumsProvider = FutureProvider<List<LikedAlbumModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.getAllLikedAlbums();
});

final likedPlaylistsProvider = FutureProvider<List<LikedPlaylistModel>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.getAllLikedPlaylists();
});

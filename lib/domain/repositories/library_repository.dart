import '../models/library_models.dart';

abstract class LibraryRepository {
  Future<List<LikedSongModel>> getAllLikedSongs();
  Future<LikedSongModel?> getLikedSong(String videoId);
  Future<void> toggleLikedSong(LikedSongModel song);
  Future<void> ensureLikedSong(LikedSongModel song);
  Future<void> deleteLikedSong(String videoId);
  Future<void> updateLikedSongMetadata(
    String videoId, {
    String? artistId,
    String? albumId,
  });

  Future<List<FollowedArtistModel>> getAllFollowedArtists();
  Future<FollowedArtistModel?> getFollowedArtist(String artistId);
  Future<void> toggleFollowedArtist(FollowedArtistModel artist);
  Future<void> ensureFollowedArtist(FollowedArtistModel artist);
  Future<void> deleteFollowedArtist(String artistId);

  Future<List<LikedAlbumModel>> getAllLikedAlbums();
  Future<LikedAlbumModel?> getLikedAlbum(String albumId);
  Future<void> toggleLikedAlbum(LikedAlbumModel album);
  Future<void> ensureLikedAlbum(LikedAlbumModel album);
  Future<void> deleteLikedAlbum(String albumId);

  Future<List<LikedPlaylistModel>> getAllLikedPlaylists();
  Future<LikedPlaylistModel?> getLikedPlaylist(String playlistId);
  Future<void> toggleLikedPlaylist(LikedPlaylistModel playlist);
  Future<void> ensureLikedPlaylist(LikedPlaylistModel playlist);
  Future<void> deleteLikedPlaylist(String playlistId);
  Future<void> updateLikedPlaylistThumbnail(
    String playlistId,
    String thumbnailUrl,
  );

  Future<List<LocalPlaylistModel>> getAllPlaylists();
  Future<int> createPlaylist(String name, {String? description});
  Future<int> createPlaylistWithDate(String name, {String? description, required DateTime createdAt});
  Future<void> updatePlaylist(int id, {String? name, String? description});
  Future<void> deletePlaylist(int id);
  Future<List<PlaylistEntryModel>> getPlaylistEntries(int playlistId);
  Future<void> addEntry(
    int playlistId,
    String videoId,
    int position, {
    String? title,
    String? artist,
    String? thumbnailUrl,
  });
  Future<void> removeEntry(int playlistId, String videoId);

  Future<List<DownloadModel>> getAllDownloads();
  Future<DownloadModel?> getDownload(String videoId);
  Future<void> insertDownload({
    required String videoId,
    required String title,
    required String artist,
    required String status,
    String? thumbnailUrl,
    String? localPath,
    String? format,
    int? fileSize,
    DateTime? downloadedAt,
  });
  Future<void> deleteDownload(String videoId);

  Future<List<HistoryModel>> getRecentHistory({int limit = 50});
  Future<void> recordPlay(
    String videoId,
    String title,
    String artist, {
    String? thumbnailUrl,
  });
  Future<void> insertHistoryEntry(
    String videoId,
    String title,
    String artist, {
    String? thumbnailUrl,
    required DateTime playedAt,
    int playCount = 1,
  });
  Future<void> clearHistory();

  Future<void> insertSearchEntry(String query);
  Future<void> insertSearchEntryWithDate(String query, {required DateTime searchedAt});
  Future<List<SearchHistoryModel>> getRecentSearches({int limit = 10});
  Future<void> clearSearchHistory();
}

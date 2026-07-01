import '../models/library_models.dart';

abstract class LibraryRepository {
  Future<List<LikedSongModel>> getAllLikedSongs();
  Stream<List<LikedSongModel>> watchAllLikedSongs();
  Future<LikedSongModel?> getLikedSong(String videoId);
  Stream<LikedSongModel?> watchLikedSong(String videoId);
  Future<void> toggleLikedSong(LikedSongModel song);
  Future<void> ensureLikedSong(LikedSongModel song);
  Future<void> deleteLikedSong(String videoId);
  Future<void> updateLikedSongMetadata(
    String videoId, {
    String? artistId,
    String? albumId,
  });
  Future<List<LikedSongModel>> getForgottenFavorites({int daysLimit = 30});
  Stream<List<LikedSongModel>> watchForgottenFavorites({int daysLimit = 30});

  Future<List<FollowedArtistModel>> getAllFollowedArtists();
  Stream<List<FollowedArtistModel>> watchAllFollowedArtists();
  Future<FollowedArtistModel?> getFollowedArtist(String artistId);
  Stream<FollowedArtistModel?> watchFollowedArtist(String artistId);
  Future<void> toggleFollowedArtist(FollowedArtistModel artist);
  Future<void> ensureFollowedArtist(FollowedArtistModel artist);
  Future<void> deleteFollowedArtist(String artistId);

  Future<List<LikedAlbumModel>> getAllLikedAlbums();
  Stream<List<LikedAlbumModel>> watchAllLikedAlbums();
  Future<LikedAlbumModel?> getLikedAlbum(String albumId);
  Stream<LikedAlbumModel?> watchLikedAlbum(String albumId);
  Future<void> toggleLikedAlbum(LikedAlbumModel album);
  Future<void> ensureLikedAlbum(LikedAlbumModel album);
  Future<void> deleteLikedAlbum(String albumId);

  Future<List<LikedPlaylistModel>> getAllLikedPlaylists();
  Stream<List<LikedPlaylistModel>> watchAllLikedPlaylists();
  Future<LikedPlaylistModel?> getLikedPlaylist(String playlistId);
  Stream<LikedPlaylistModel?> watchLikedPlaylist(String playlistId);
  Future<void> toggleLikedPlaylist(LikedPlaylistModel playlist);
  Future<void> ensureLikedPlaylist(LikedPlaylistModel playlist);
  Future<void> deleteLikedPlaylist(String playlistId);
  Future<void> updateLikedPlaylistThumbnail(
    String playlistId,
    String thumbnailUrl,
  );

  Future<List<LocalPlaylistModel>> getAllPlaylists();
  Stream<List<LocalPlaylistModel>> watchAllPlaylists();
  Future<int> createPlaylist(String name, {String? description});
  Future<int> createPlaylistWithDate(
    String name, {
    String? description,
    required DateTime createdAt,
  });
  Future<void> updatePlaylist(int id, {String? name, String? description});
  Future<void> deletePlaylist(int id);
  Future<List<PlaylistEntryModel>> getPlaylistEntries(int playlistId);
  Stream<List<PlaylistEntryModel>> watchPlaylistEntries(int playlistId);
  Future<void> addEntry(
    int playlistId,
    String videoId,
    int position, {
    String? title,
    String? artist,
    String? thumbnailUrl,
    int? duration,
    bool isVideo = false,
    bool isExplicit = false,
  });
  Future<void> removeEntry(int playlistId, String videoId);
  Future<void> reorderEntries(int playlistId, List<String> videoIds);

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
    bool isVideo = false,
    bool isExplicit = false,
  });
  Future<void> deleteDownload(String videoId);

  Future<List<HistoryModel>> getRecentHistory({int limit = 50});
  Stream<List<HistoryModel>> watchRecentHistory({int limit = 50});
  Future<List<HistoryModel>> getMostPlayedSongs({int limit = 50});
  Stream<List<HistoryModel>> watchMostPlayedSongs({int limit = 50});
  Future<void> recordPlay(
    String videoId,
    String title,
    String artist, {
    String? thumbnailUrl,
    int? duration,
    bool isVideo = false,
    bool isExplicit = false,
  });
  Future<void> insertHistoryEntry(
    String videoId,
    String title,
    String artist, {
    String? thumbnailUrl,
    int? duration,
    required DateTime playedAt,
    int playCount = 1,
    bool isVideo = false,
    bool isExplicit = false,
  });
  Future<void> clearHistory();

  Future<void> insertSearchEntry(String query);
  Future<void> insertSearchEntryWithDate(
    String query, {
    required DateTime searchedAt,
  });
  Future<List<SearchHistoryModel>> getRecentSearches({int limit = 10});
  Future<void> clearSearchHistory();
  Future<void> deleteSearchEntry(String query);

  Future<void> updateSongMetadata(
    String videoId,
    int duration,
    bool isExplicit,
  );
  Future<List<String>> getTrackIdsMissingMetadata({int limit = 15});
  Future<int> getTrackCountMissingMetadata();
}

import '../../data/datasources/local/database.dart';

abstract class LibraryRepository {
  Future<List<LikedSong>> getAllLikedSongs();
  Future<LikedSong?> getLikedSong(String videoId);
  Future<void> toggleLikedSong(LikedSong song);
  Future<void> deleteLikedSong(String videoId);

  Future<List<FollowedArtist>> getAllFollowedArtists();
  Future<void> toggleFollowedArtist(FollowedArtist artist);
  Future<void> deleteFollowedArtist(String artistId);

  Future<List<LocalPlaylist>> getAllPlaylists();
  Future<int> createPlaylist(String name, {String? description});
  Future<void> deletePlaylist(int id);
  Future<List<PlaylistEntry>> getPlaylistEntries(int playlistId);
  Future<void> addEntry(int playlistId, String videoId, int position);
  Future<void> removeEntry(int playlistId, String videoId);

  Future<List<Download>> getAllDownloads();
  Future<void> insertDownload(DownloadsCompanion entry);
  Future<void> deleteDownload(String videoId);

  Future<List<HistoryData>> getRecentHistory({int limit = 50});
  Future<void> recordPlay(String videoId, String title, String artist);
  Future<void> clearHistory();

  Future<void> insertSearchEntry(String query);
  Future<List<SearchHistoryData>> getRecentSearches({int limit = 10});
  Future<void> clearSearchHistory();
}

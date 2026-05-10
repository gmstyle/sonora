import '../../domain/repositories/library_repository.dart';
import '../datasources/local/database.dart';
import '../datasources/local/daos/library_dao.dart';
import '../datasources/local/daos/playlists_dao.dart';
import '../datasources/local/daos/downloads_dao.dart';
import '../datasources/local/daos/history_dao.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  final LibraryDao _libraryDao;
  final PlaylistsDao _playlistsDao;
  final DownloadsDao _downloadsDao;
  final HistoryDao _historyDao;

  LibraryRepositoryImpl(
    this._libraryDao,
    this._playlistsDao,
    this._downloadsDao,
    this._historyDao,
  );

  @override
  Future<List<LikedSong>> getAllLikedSongs() =>
      _libraryDao.getAllLikedSongs();

  @override
  Future<LikedSong?> getLikedSong(String videoId) =>
      _libraryDao.getLikedSong(videoId);

  @override
  Future<void> toggleLikedSong(LikedSong song) async {
    final existing = await _libraryDao.getLikedSong(song.videoId);
    if (existing != null) {
      await _libraryDao.deleteLikedSong(song.videoId);
    } else {
      await _libraryDao.insertLikedSong(song.toCompanion(true));
    }
  }

  @override
  Future<void> deleteLikedSong(String videoId) =>
      _libraryDao.deleteLikedSong(videoId);

  @override
  Future<List<FollowedArtist>> getAllFollowedArtists() =>
      _libraryDao.getAllFollowedArtists();

  @override
  Future<void> toggleFollowedArtist(FollowedArtist artist) async {
    final existing = await _libraryDao.getFollowedArtist(artist.artistId);
    if (existing != null) {
      await _libraryDao.deleteFollowedArtist(artist.artistId);
    } else {
      await _libraryDao.insertFollowedArtist(artist.toCompanion(true));
    }
  }

  @override
  Future<void> deleteFollowedArtist(String artistId) =>
      _libraryDao.deleteFollowedArtist(artistId);

  @override
  Future<List<LocalPlaylist>> getAllPlaylists() =>
      _playlistsDao.getAllPlaylists();

  @override
  Future<int> createPlaylist(String name, {String? description}) =>
      _playlistsDao.createPlaylist(name, description: description);

  @override
  Future<void> deletePlaylist(int id) => _playlistsDao.deletePlaylist(id);

  @override
  Future<List<PlaylistEntry>> getPlaylistEntries(int playlistId) =>
      _playlistsDao.getPlaylistEntries(playlistId);

  @override
  Future<void> addEntry(int playlistId, String videoId, int position) =>
      _playlistsDao.addEntry(playlistId, videoId, position);

  @override
  Future<void> removeEntry(int playlistId, String videoId) =>
      _playlistsDao.removeEntry(playlistId, videoId);

  @override
  Future<List<Download>> getAllDownloads() => _downloadsDao.getAllDownloads();

  @override
  Future<void> insertDownload(DownloadsCompanion entry) =>
      _downloadsDao.insertDownload(entry);

  @override
  Future<void> deleteDownload(String videoId) =>
      _downloadsDao.deleteDownload(videoId);

  @override
  Future<List<HistoryData>> getRecentHistory({int limit = 50}) =>
      _historyDao.getRecentHistory(limit: limit);

  @override
  Future<void> recordPlay(String videoId, String title, String artist) =>
      _historyDao.recordPlay(videoId, title, artist);

  @override
  Future<void> clearHistory() => _historyDao.clearHistory();

  @override
  Future<void> insertSearchEntry(String query) =>
      _historyDao.insertSearchEntry(query);

  @override
  Future<List<SearchHistoryData>> getRecentSearches({int limit = 10}) =>
      _historyDao.getRecentSearches(limit: limit);

  @override
  Future<void> clearSearchHistory() => _historyDao.clearSearchHistory();
}

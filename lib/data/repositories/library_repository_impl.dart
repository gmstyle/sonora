import 'package:drift/drift.dart';

import '../../domain/models/library_models.dart';
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

  // ── Liked Songs ──────────────────────────────────────────────

  @override
  Future<List<LikedSongModel>> getAllLikedSongs() async {
    final rows = await _libraryDao.getAllLikedSongs();
    return rows.map(_mapLikedSong).toList();
  }

  @override
  Future<LikedSongModel?> getLikedSong(String videoId) async {
    final row = await _libraryDao.getLikedSong(videoId);
    return row != null ? _mapLikedSong(row) : null;
  }

  @override
  Future<void> toggleLikedSong(LikedSongModel song) async {
    final existing = await _libraryDao.getLikedSong(song.videoId);
    if (existing != null) {
      await _libraryDao.deleteLikedSong(song.videoId);
    } else {
      await _libraryDao.insertLikedSong(
        LikedSongsCompanion.insert(
          videoId: song.videoId,
          title: song.title,
          artist: song.artist,
          thumbnailUrl: Value(song.thumbnailUrl),
          addedAt: song.addedAt,
        ),
      );
    }
  }

  @override
  Future<void> deleteLikedSong(String videoId) =>
      _libraryDao.deleteLikedSong(videoId);

  // ── Followed Artists ─────────────────────────────────────────

  @override
  Future<List<FollowedArtistModel>> getAllFollowedArtists() async {
    final rows = await _libraryDao.getAllFollowedArtists();
    return rows.map(_mapFollowedArtist).toList();
  }

  @override
  Future<FollowedArtistModel?> getFollowedArtist(String artistId) async {
    final row = await _libraryDao.getFollowedArtist(artistId);
    return row != null ? _mapFollowedArtist(row) : null;
  }

  @override
  Future<void> toggleFollowedArtist(FollowedArtistModel artist) async {
    final existing = await _libraryDao.getFollowedArtist(artist.artistId);
    if (existing != null) {
      await _libraryDao.deleteFollowedArtist(artist.artistId);
    } else {
      await _libraryDao.insertFollowedArtist(
        FollowedArtistsCompanion.insert(
          artistId: artist.artistId,
          name: artist.name,
          thumbnailUrl: Value(artist.thumbnailUrl),
        ),
      );
    }
  }

  @override
  Future<void> deleteFollowedArtist(String artistId) =>
      _libraryDao.deleteFollowedArtist(artistId);

  // ── Playlists ─────────────────────────────────────────────────

  @override
  Future<List<LocalPlaylistModel>> getAllPlaylists() async {
    final rows = await _playlistsDao.getAllPlaylists();
    return rows.map(_mapPlaylist).toList();
  }

  @override
  Future<int> createPlaylist(String name, {String? description}) =>
      _playlistsDao.createPlaylist(name, description: description);

  @override
  Future<void> updatePlaylist(int id, {String? name, String? description}) =>
      _playlistsDao.updatePlaylist(id, name: name, description: description);

  @override
  Future<void> deletePlaylist(int id) => _playlistsDao.deletePlaylist(id);

  @override
  Future<List<PlaylistEntryModel>> getPlaylistEntries(int playlistId) async {
    final rows = await _playlistsDao.getPlaylistEntries(playlistId);
    return rows
        .map(
          (r) => PlaylistEntryModel(
            playlistId: r.playlistId,
            videoId: r.videoId,
            position: r.position,
          ),
        )
        .toList();
  }

  @override
  Future<void> addEntry(int playlistId, String videoId, int position) =>
      _playlistsDao.addEntry(playlistId, videoId, position);

  @override
  Future<void> removeEntry(int playlistId, String videoId) =>
      _playlistsDao.removeEntry(playlistId, videoId);

  // ── Downloads ─────────────────────────────────────────────────

  @override
  Future<List<DownloadModel>> getAllDownloads() async {
    final rows = await _downloadsDao.getAllDownloads();
    return rows
        .map(
          (r) => DownloadModel(
            videoId: r.videoId,
            localPath: r.localPath,
            format: r.format,
            fileSize: r.fileSize,
            downloadedAt: r.downloadedAt,
            status: r.status,
          ),
        )
        .toList();
  }

  @override
  Future<void> insertDownload({
    required String videoId,
    required String status,
    String? localPath,
    String? format,
    int? fileSize,
    DateTime? downloadedAt,
  }) => _downloadsDao.insertDownload(
    DownloadsCompanion.insert(
      videoId: videoId,
      status: status,
      localPath: Value(localPath),
      format: Value(format),
      fileSize: Value(fileSize),
      downloadedAt: Value(downloadedAt),
    ),
  );

  @override
  Future<void> deleteDownload(String videoId) =>
      _downloadsDao.deleteDownload(videoId);

  // ── History ───────────────────────────────────────────────────

  @override
  Future<List<HistoryModel>> getRecentHistory({int limit = 50}) async {
    final rows = await _historyDao.getRecentHistory(limit: limit);
    return rows
        .map(
          (r) => HistoryModel(
            id: r.id,
            videoId: r.videoId,
            title: r.title,
            artist: r.artist,
            thumbnailUrl: r.thumbnailUrl,
            playedAt: r.playedAt,
            playCount: r.playCount,
          ),
        )
        .toList();
  }

  @override
  Future<void> recordPlay(String videoId, String title, String artist, {String? thumbnailUrl}) =>
      _historyDao.recordPlay(videoId, title, artist, thumbnailUrl: thumbnailUrl);

  @override
  Future<void> clearHistory() => _historyDao.clearHistory();

  // ── Search History ────────────────────────────────────────────

  @override
  Future<void> insertSearchEntry(String query) =>
      _historyDao.insertSearchEntry(query);

  @override
  Future<List<SearchHistoryModel>> getRecentSearches({int limit = 10}) async {
    final rows = await _historyDao.getRecentSearches(limit: limit);
    return rows
        .map(
          (r) => SearchHistoryModel(
            id: r.id,
            query: r.query,
            searchedAt: r.searchedAt,
          ),
        )
        .toList();
  }

  @override
  Future<void> clearSearchHistory() => _historyDao.clearSearchHistory();

  // ── Mapping helpers ───────────────────────────────────────────

  LikedSongModel _mapLikedSong(LikedSong r) => LikedSongModel(
    videoId: r.videoId,
    title: r.title,
    artist: r.artist,
    thumbnailUrl: r.thumbnailUrl,
    addedAt: r.addedAt,
  );

  FollowedArtistModel _mapFollowedArtist(FollowedArtist r) =>
      FollowedArtistModel(
        artistId: r.artistId,
        name: r.name,
        thumbnailUrl: r.thumbnailUrl,
      );

  LocalPlaylistModel _mapPlaylist(LocalPlaylist r) => LocalPlaylistModel(
    id: r.id,
    name: r.name,
    description: r.description,
    createdAt: r.createdAt,
  );
}

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
  Stream<List<LikedSongModel>> watchAllLikedSongs() {
    return _libraryDao.watchAllLikedSongs().map(
      (rows) => rows.map(_mapLikedSong).toList(),
    );
  }

  @override
  Future<LikedSongModel?> getLikedSong(String videoId) async {
    final row = await _libraryDao.getLikedSong(videoId);
    return row != null ? _mapLikedSong(row) : null;
  }

  @override
  Stream<LikedSongModel?> watchLikedSong(String videoId) {
    return _libraryDao
        .watchLikedSong(videoId)
        .map((row) => row != null ? _mapLikedSong(row) : null);
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
          artistId: Value(song.artistId),
          albumId: Value(song.albumId),
          addedAt: song.addedAt,
          isVideo: Value(song.isVideo),
          duration: Value(song.duration),
          isExplicit: Value(song.isExplicit),
        ),
      );
    }
  }

  @override
  Future<void> ensureLikedSong(LikedSongModel song) async {
    await _libraryDao.insertLikedSong(
      LikedSongsCompanion.insert(
        videoId: song.videoId,
        title: song.title,
        artist: song.artist,
        thumbnailUrl: Value(song.thumbnailUrl),
        artistId: Value(song.artistId),
        albumId: Value(song.albumId),
        addedAt: song.addedAt,
        isVideo: Value(song.isVideo),
        duration: Value(song.duration),
        isExplicit: Value(song.isExplicit),
      ),
    );
  }

  @override
  Future<void> deleteLikedSong(String videoId) =>
      _libraryDao.deleteLikedSong(videoId);

  @override
  Future<void> updateLikedSongMetadata(
    String videoId, {
    String? artistId,
    String? albumId,
  }) => _libraryDao.updateLikedSongMetadata(
    videoId,
    artistId: artistId,
    albumId: albumId,
  );

  @override
  Future<List<LikedSongModel>> getForgottenFavorites({
    int daysLimit = 30,
  }) async {
    final rows = await _libraryDao.getForgottenFavorites(daysLimit: daysLimit);
    return rows.map(_mapLikedSong).toList();
  }

  @override
  Stream<List<LikedSongModel>> watchForgottenFavorites({int daysLimit = 30}) {
    return _libraryDao
        .watchForgottenFavorites(daysLimit: daysLimit)
        .map((rows) => rows.map(_mapLikedSong).toList());
  }

  // ── Followed Artists ─────────────────────────────────────────

  @override
  Future<List<FollowedArtistModel>> getAllFollowedArtists() async {
    final rows = await _libraryDao.getAllFollowedArtists();
    return rows.map(_mapFollowedArtist).toList();
  }

  @override
  Stream<List<FollowedArtistModel>> watchAllFollowedArtists() {
    return _libraryDao.watchAllFollowedArtists().map(
      (rows) => rows.map(_mapFollowedArtist).toList(),
    );
  }

  @override
  Future<FollowedArtistModel?> getFollowedArtist(String artistId) async {
    final row = await _libraryDao.getFollowedArtist(artistId);
    return row != null ? _mapFollowedArtist(row) : null;
  }

  @override
  Stream<FollowedArtistModel?> watchFollowedArtist(String artistId) {
    return _libraryDao
        .watchFollowedArtist(artistId)
        .map((row) => row != null ? _mapFollowedArtist(row) : null);
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
          addedAt: Value(artist.addedAt),
        ),
      );
    }
  }

  @override
  Future<void> ensureFollowedArtist(FollowedArtistModel artist) async {
    await _libraryDao.insertFollowedArtist(
      FollowedArtistsCompanion.insert(
        artistId: artist.artistId,
        name: artist.name,
        thumbnailUrl: Value(artist.thumbnailUrl),
        addedAt: Value(artist.addedAt),
      ),
    );
  }

  @override
  Future<void> deleteFollowedArtist(String artistId) =>
      _libraryDao.deleteFollowedArtist(artistId);

  // ── Liked Albums ─────────────────────────────────────────────

  @override
  Future<List<LikedAlbumModel>> getAllLikedAlbums() async {
    final rows = await _libraryDao.getAllLikedAlbums();
    return rows.map(_mapLikedAlbum).toList();
  }

  @override
  Stream<List<LikedAlbumModel>> watchAllLikedAlbums() {
    return _libraryDao.watchAllLikedAlbums().map(
      (rows) => rows.map(_mapLikedAlbum).toList(),
    );
  }

  @override
  Future<LikedAlbumModel?> getLikedAlbum(String albumId) async {
    final row = await _libraryDao.getLikedAlbum(albumId);
    return row != null ? _mapLikedAlbum(row) : null;
  }

  @override
  Stream<LikedAlbumModel?> watchLikedAlbum(String albumId) {
    return _libraryDao
        .watchLikedAlbum(albumId)
        .map((row) => row != null ? _mapLikedAlbum(row) : null);
  }

  @override
  Future<void> toggleLikedAlbum(LikedAlbumModel album) async {
    final existing = await _libraryDao.getLikedAlbum(album.albumId);
    if (existing != null) {
      await _libraryDao.deleteLikedAlbum(album.albumId);
    } else {
      await _libraryDao.insertLikedAlbum(
        LikedAlbumsCompanion.insert(
          albumId: album.albumId,
          name: album.name,
          artistName: album.artistName,
          artistId: Value(album.artistId),
          thumbnailUrl: Value(album.thumbnailUrl),
          year: Value(album.year),
          addedAt: album.addedAt,
        ),
      );
    }
  }

  @override
  Future<void> ensureLikedAlbum(LikedAlbumModel album) async {
    await _libraryDao.insertLikedAlbum(
      LikedAlbumsCompanion.insert(
        albumId: album.albumId,
        name: album.name,
        artistName: album.artistName,
        artistId: Value(album.artistId),
        thumbnailUrl: Value(album.thumbnailUrl),
        year: Value(album.year),
        addedAt: album.addedAt,
      ),
    );
  }

  @override
  Future<void> deleteLikedAlbum(String albumId) =>
      _libraryDao.deleteLikedAlbum(albumId);

  // ── Liked Playlists ──────────────────────────────────────────

  @override
  Future<List<LikedPlaylistModel>> getAllLikedPlaylists() async {
    final rows = await _libraryDao.getAllLikedPlaylists();
    return rows.map(_mapLikedPlaylist).toList();
  }

  @override
  Stream<List<LikedPlaylistModel>> watchAllLikedPlaylists() {
    return _libraryDao.watchAllLikedPlaylists().map(
      (rows) => rows.map(_mapLikedPlaylist).toList(),
    );
  }

  @override
  Future<LikedPlaylistModel?> getLikedPlaylist(String playlistId) async {
    final row = await _libraryDao.getLikedPlaylist(playlistId);
    return row != null ? _mapLikedPlaylist(row) : null;
  }

  @override
  Stream<LikedPlaylistModel?> watchLikedPlaylist(String playlistId) {
    return _libraryDao
        .watchLikedPlaylist(playlistId)
        .map((row) => row != null ? _mapLikedPlaylist(row) : null);
  }

  @override
  Future<void> toggleLikedPlaylist(LikedPlaylistModel playlist) async {
    final existing = await _libraryDao.getLikedPlaylist(playlist.playlistId);
    if (existing != null) {
      await _libraryDao.deleteLikedPlaylist(playlist.playlistId);
    } else {
      await _libraryDao.insertLikedPlaylist(
        LikedPlaylistsCompanion.insert(
          playlistId: playlist.playlistId,
          name: playlist.name,
          thumbnailUrl: Value(playlist.thumbnailUrl),
          videoCount: Value(playlist.videoCount),
          addedAt: playlist.addedAt,
        ),
      );
    }
  }

  @override
  Future<void> ensureLikedPlaylist(LikedPlaylistModel playlist) async {
    await _libraryDao.insertLikedPlaylist(
      LikedPlaylistsCompanion.insert(
        playlistId: playlist.playlistId,
        name: playlist.name,
        thumbnailUrl: Value(playlist.thumbnailUrl),
        videoCount: Value(playlist.videoCount),
        addedAt: playlist.addedAt,
      ),
    );
  }

  @override
  Future<void> deleteLikedPlaylist(String playlistId) =>
      _libraryDao.deleteLikedPlaylist(playlistId);

  @override
  Future<void> updateLikedPlaylistThumbnail(
    String playlistId,
    String thumbnailUrl,
  ) => _libraryDao.updateLikedPlaylistThumbnail(playlistId, thumbnailUrl);

  // ── Playlists ─────────────────────────────────────────────────

  @override
  Future<List<LocalPlaylistModel>> getAllPlaylists() async {
    final rows = await _playlistsDao.getAllPlaylists();
    return rows.map(_mapPlaylist).toList();
  }

  @override
  Stream<List<LocalPlaylistModel>> watchAllPlaylists() {
    return _playlistsDao.watchAllPlaylists().map(
      (rows) => rows.map(_mapPlaylist).toList(),
    );
  }

  @override
  Future<int> createPlaylist(String name, {String? description}) =>
      _playlistsDao.createPlaylist(name, description: description);

  @override
  Future<int> createPlaylistWithDate(
    String name, {
    String? description,
    required DateTime createdAt,
  }) => _playlistsDao.createPlaylistWithDate(
    name,
    description: description,
    createdAt: createdAt,
  );

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
            title: r.title,
            artist: r.artist,
            thumbnailUrl: r.thumbnailUrl,
            isVideo: r.isVideo,
            duration: r.duration,
            isExplicit: r.isExplicit,
          ),
        )
        .toList();
  }

  @override
  Stream<List<PlaylistEntryModel>> watchPlaylistEntries(int playlistId) {
    return _playlistsDao
        .watchPlaylistEntries(playlistId)
        .map(
          (rows) =>
              rows
                  .map(
                    (r) => PlaylistEntryModel(
                      playlistId: r.playlistId,
                      videoId: r.videoId,
                      position: r.position,
                      title: r.title,
                      artist: r.artist,
                      thumbnailUrl: r.thumbnailUrl,
                      isVideo: r.isVideo,
                      duration: r.duration,
                      isExplicit: r.isExplicit,
                    ),
                  )
                  .toList(),
        );
  }

  @override
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
  }) => _playlistsDao.addEntry(
    playlistId,
    videoId,
    position,
    title: title,
    artist: artist,
    thumbnailUrl: thumbnailUrl,
    duration: duration,
    isVideo: isVideo,
    isExplicit: isExplicit,
  );

  @override
  Future<void> removeEntry(int playlistId, String videoId) =>
      _playlistsDao.removeEntry(playlistId, videoId);

  @override
  Future<void> reorderEntries(int playlistId, List<String> videoIds) =>
      _playlistsDao.reorderEntries(playlistId, videoIds);

  // ── Downloads ─────────────────────────────────────────────────

  @override
  Future<DownloadModel?> getDownload(String videoId) async {
    final row = await _downloadsDao.getDownload(videoId);
    if (row == null) return null;
    return DownloadModel(
      videoId: row.videoId,
      title: row.title ?? '',
      artist: row.artist ?? '',
      thumbnailUrl: row.thumbnailUrl,
      localPath: row.localPath,
      format: row.format,
      fileSize: row.fileSize,
      downloadedAt: row.downloadedAt,
      status: row.status,
      isVideo: row.isVideo,
      isExplicit: row.isExplicit,
    );
  }

  @override
  Future<List<DownloadModel>> getAllDownloads() async {
    final rows = await _downloadsDao.getAllDownloads();
    return rows
        .map(
          (r) => DownloadModel(
            videoId: r.videoId,
            title: r.title ?? '',
            artist: r.artist ?? '',
            thumbnailUrl: r.thumbnailUrl,
            localPath: r.localPath,
            format: r.format,
            fileSize: r.fileSize,
            downloadedAt: r.downloadedAt,
            status: r.status,
            isVideo: r.isVideo,
            isExplicit: r.isExplicit,
          ),
        )
        .toList();
  }

  @override
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
  }) => _downloadsDao.insertDownload(
    DownloadsCompanion.insert(
      videoId: videoId,
      title: Value<String?>(title),
      artist: Value<String?>(artist),
      thumbnailUrl: Value(thumbnailUrl),
      status: status,
      localPath: Value(localPath),
      format: Value(format),
      fileSize: Value(fileSize),
      downloadedAt: Value(downloadedAt),
      isVideo: Value(isVideo),
      isExplicit: Value(isExplicit),
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
            isVideo: r.isVideo,
            duration: r.duration,
            isExplicit: r.isExplicit,
          ),
        )
        .toList();
  }

  @override
  Stream<List<HistoryModel>> watchRecentHistory({int limit = 50}) {
    return _historyDao
        .watchRecentHistory(limit: limit)
        .map(
          (rows) =>
              rows
                  .map(
                    (r) => HistoryModel(
                      id: r.id,
                      videoId: r.videoId,
                      title: r.title,
                      artist: r.artist,
                      thumbnailUrl: r.thumbnailUrl,
                      playedAt: r.playedAt,
                      playCount: r.playCount,
                      isVideo: r.isVideo,
                      duration: r.duration,
                      isExplicit: r.isExplicit,
                    ),
                  )
                  .toList(),
        );
  }

  @override
  Future<List<HistoryModel>> getMostPlayedSongs({int limit = 50}) async {
    final rows = await _historyDao.getMostPlayedSongs(limit: limit);
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
            isVideo: r.isVideo,
            duration: r.duration,
            isExplicit: r.isExplicit,
          ),
        )
        .toList();
  }

  @override
  Stream<List<HistoryModel>> watchMostPlayedSongs({int limit = 50}) {
    return _historyDao
        .watchMostPlayedSongs(limit: limit)
        .map(
          (rows) =>
              rows
                  .map(
                    (r) => HistoryModel(
                      id: r.id,
                      videoId: r.videoId,
                      title: r.title,
                      artist: r.artist,
                      thumbnailUrl: r.thumbnailUrl,
                      playedAt: r.playedAt,
                      playCount: r.playCount,
                      isVideo: r.isVideo,
                      duration: r.duration,
                      isExplicit: r.isExplicit,
                    ),
                  )
                  .toList(),
        );
  }

  @override
  Future<void> recordPlay(
    String videoId,
    String title,
    String artist, {
    String? thumbnailUrl,
    int? duration,
    bool isVideo = false,
    bool isExplicit = false,
  }) => _historyDao.recordPlay(
    videoId,
    title,
    artist,
    thumbnailUrl: thumbnailUrl,
    duration: duration,
    isVideo: isVideo,
    isExplicit: isExplicit,
  );

  @override
  Future<void> clearHistory() => _historyDao.clearHistory();

  @override
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
  }) => _historyDao.insertHistoryRaw(
    videoId,
    title,
    artist,
    thumbnailUrl: thumbnailUrl,
    duration: duration,
    playedAt: playedAt,
    playCount: playCount,
    isVideo: isVideo,
    isExplicit: isExplicit,
  );

  // ── Search History ────────────────────────────────────────────

  @override
  Future<void> insertSearchEntry(String query) =>
      _historyDao.insertSearchEntry(query);

  @override
  Future<void> insertSearchEntryWithDate(
    String query, {
    required DateTime searchedAt,
  }) => _historyDao.insertSearchEntryRaw(query, searchedAt: searchedAt);

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

  @override
  Future<void> deleteSearchEntry(String query) =>
      _historyDao.deleteSearchEntry(query);

  // ── Mapping helpers ───────────────────────────────────────────

  LikedSongModel _mapLikedSong(LikedSong r) => LikedSongModel(
    videoId: r.videoId,
    title: r.title,
    artist: r.artist,
    thumbnailUrl: r.thumbnailUrl,
    artistId: r.artistId,
    albumId: r.albumId,
    addedAt: r.addedAt,
    isVideo: r.isVideo,
    duration: r.duration,
    isExplicit: r.isExplicit,
  );

  FollowedArtistModel _mapFollowedArtist(FollowedArtist r) =>
      FollowedArtistModel(
        artistId: r.artistId,
        name: r.name,
        thumbnailUrl: r.thumbnailUrl,
        addedAt: r.addedAt,
      );

  LocalPlaylistModel _mapPlaylist(LocalPlaylist r) => LocalPlaylistModel(
    id: r.id,
    name: r.name,
    description: r.description,
    createdAt: r.createdAt,
  );

  LikedAlbumModel _mapLikedAlbum(LikedAlbum r) => LikedAlbumModel(
    albumId: r.albumId,
    name: r.name,
    artistName: r.artistName,
    artistId: r.artistId,
    thumbnailUrl: r.thumbnailUrl,
    year: r.year,
    addedAt: r.addedAt,
  );

  LikedPlaylistModel _mapLikedPlaylist(LikedPlaylist r) => LikedPlaylistModel(
    playlistId: r.playlistId,
    name: r.name,
    thumbnailUrl: r.thumbnailUrl,
    videoCount: r.videoCount,
    addedAt: r.addedAt,
  );

  @override
  Future<void> updateSongMetadata(
    String videoId,
    int duration,
    bool isExplicit,
  ) => _libraryDao.db.updateSongMetadata(videoId, duration, isExplicit);

  @override
  Future<List<String>> getTrackIdsMissingMetadata({int limit = 15}) =>
      _libraryDao.db.getTrackIdsMissingMetadata(limit: limit);

  @override
  Future<int> getTrackCountMissingMetadata() =>
      _libraryDao.db.getTrackCountMissingMetadata();

  @override
  Future<List<String>> getAlbumIdsMissingArtistId({int limit = 10}) =>
      _libraryDao.db.getAlbumIdsMissingArtistId(limit: limit);

  @override
  Future<void> updateAlbumArtistId(String albumId, String artistId) =>
      _libraryDao.db.updateAlbumArtistId(albumId, artistId);

  @override
  Future<int> getAlbumCountMissingArtistId() =>
      _libraryDao.db.getAlbumCountMissingArtistId();
}

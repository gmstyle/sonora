import 'package:drift/drift.dart';
import '../database.dart';

class LibraryDao extends DatabaseAccessor<AppDatabase> {
  LibraryDao(super.db);

  Future<List<LikedSong>> getAllLikedSongs() => select(db.likedSongs).get();

  Stream<List<LikedSong>> watchAllLikedSongs() => select(db.likedSongs).watch();

  Future<LikedSong?> getLikedSong(String videoId) =>
      (select(db.likedSongs)
        ..where((t) => t.videoId.equals(videoId))).getSingleOrNull();

  Stream<LikedSong?> watchLikedSong(String videoId) =>
      (select(db.likedSongs)
        ..where((t) => t.videoId.equals(videoId))).watchSingleOrNull();

  Future<void> insertLikedSong(LikedSongsCompanion entry) =>
      into(db.likedSongs).insertOnConflictUpdate(entry);

  Future<void> deleteLikedSong(String videoId) =>
      (delete(db.likedSongs)..where((t) => t.videoId.equals(videoId))).go();

  Future<void> updateLikedSongMetadata(
    String videoId, {
    required String? artistId,
    required String? albumId,
  }) => (update(db.likedSongs)..where((t) => t.videoId.equals(videoId))).write(
    LikedSongsCompanion(artistId: Value(artistId), albumId: Value(albumId)),
  );

  Future<List<FollowedArtist>> getAllFollowedArtists() =>
      select(db.followedArtists).get();

  Stream<List<FollowedArtist>> watchAllFollowedArtists() =>
      select(db.followedArtists).watch();

  Future<FollowedArtist?> getFollowedArtist(String artistId) =>
      (select(db.followedArtists)
        ..where((t) => t.artistId.equals(artistId))).getSingleOrNull();

  Stream<FollowedArtist?> watchFollowedArtist(String artistId) =>
      (select(db.followedArtists)
        ..where((t) => t.artistId.equals(artistId))).watchSingleOrNull();

  Future<void> insertFollowedArtist(FollowedArtistsCompanion entry) =>
      into(db.followedArtists).insertOnConflictUpdate(entry);

  Future<void> deleteFollowedArtist(String artistId) =>
      (delete(db.followedArtists)
        ..where((t) => t.artistId.equals(artistId))).go();

  // ── Liked Albums ─────────────────────────────────────────────

  Future<List<LikedAlbum>> getAllLikedAlbums() => select(db.likedAlbums).get();

  Stream<List<LikedAlbum>> watchAllLikedAlbums() =>
      select(db.likedAlbums).watch();

  Future<LikedAlbum?> getLikedAlbum(String albumId) =>
      (select(db.likedAlbums)
        ..where((t) => t.albumId.equals(albumId))).getSingleOrNull();

  Stream<LikedAlbum?> watchLikedAlbum(String albumId) =>
      (select(db.likedAlbums)
        ..where((t) => t.albumId.equals(albumId))).watchSingleOrNull();

  Future<void> insertLikedAlbum(LikedAlbumsCompanion entry) =>
      into(db.likedAlbums).insertOnConflictUpdate(entry);

  Future<void> deleteLikedAlbum(String albumId) =>
      (delete(db.likedAlbums)..where((t) => t.albumId.equals(albumId))).go();

  // ── Liked Playlists ──────────────────────────────────────────

  Future<List<LikedPlaylist>> getAllLikedPlaylists() =>
      select(db.likedPlaylists).get();

  Stream<List<LikedPlaylist>> watchAllLikedPlaylists() =>
      select(db.likedPlaylists).watch();

  Future<LikedPlaylist?> getLikedPlaylist(String playlistId) =>
      (select(db.likedPlaylists)
        ..where((t) => t.playlistId.equals(playlistId))).getSingleOrNull();

  Stream<LikedPlaylist?> watchLikedPlaylist(String playlistId) =>
      (select(db.likedPlaylists)
        ..where((t) => t.playlistId.equals(playlistId))).watchSingleOrNull();

  Future<void> insertLikedPlaylist(LikedPlaylistsCompanion entry) =>
      into(db.likedPlaylists).insertOnConflictUpdate(entry);

  Future<void> deleteLikedPlaylist(String playlistId) =>
      (delete(db.likedPlaylists)
        ..where((t) => t.playlistId.equals(playlistId))).go();

  Future<void> updateLikedPlaylistThumbnail(
    String playlistId,
    String thumbnailUrl,
  ) => (update(db.likedPlaylists)..where(
    (t) => t.playlistId.equals(playlistId),
  )).write(LikedPlaylistsCompanion(thumbnailUrl: Value(thumbnailUrl)));

  Future<List<LikedSong>> getForgottenFavorites({int daysLimit = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysLimit));
    final query = select(db.likedSongs).join([
      leftOuterJoin(
        db.history,
        db.history.videoId.equalsExp(db.likedSongs.videoId),
      ),
    ]);
    query.where(
      db.history.playedAt.isNull() |
          db.history.playedAt.isSmallerThanValue(cutoff),
    );
    final rows = await query.get();
    return rows.map((row) => row.readTable(db.likedSongs)).toList();
  }

  Stream<List<LikedSong>> watchForgottenFavorites({int daysLimit = 30}) {
    final cutoff = DateTime.now().subtract(Duration(days: daysLimit));
    final query = select(db.likedSongs).join([
      leftOuterJoin(
        db.history,
        db.history.videoId.equalsExp(db.likedSongs.videoId),
      ),
    ]);
    query.where(
      db.history.playedAt.isNull() |
          db.history.playedAt.isSmallerThanValue(cutoff),
    );
    return query.watch().map((rows) {
      return rows.map((row) => row.readTable(db.likedSongs)).toList();
    });
  }
}

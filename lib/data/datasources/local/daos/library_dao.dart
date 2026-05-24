import 'package:drift/drift.dart';
import '../database.dart';

class LibraryDao extends DatabaseAccessor<AppDatabase> {
  LibraryDao(super.db);

  Future<List<LikedSong>> getAllLikedSongs() => select(db.likedSongs).get();

  Future<LikedSong?> getLikedSong(String videoId) =>
      (select(db.likedSongs)
        ..where((t) => t.videoId.equals(videoId))).getSingleOrNull();

  Future<void> insertLikedSong(LikedSongsCompanion entry) =>
      into(db.likedSongs).insertOnConflictUpdate(entry);

  Future<void> deleteLikedSong(String videoId) =>
      (delete(db.likedSongs)..where((t) => t.videoId.equals(videoId))).go();

  Future<void> updateLikedSongMetadata(
    String videoId, {
    required String? artistId,
    required String? albumId,
  }) =>
      (update(db.likedSongs)
        ..where((t) => t.videoId.equals(videoId)))
          .write(LikedSongsCompanion(
            artistId: Value(artistId),
            albumId: Value(albumId),
          ));

  Future<List<FollowedArtist>> getAllFollowedArtists() =>
      select(db.followedArtists).get();

  Future<FollowedArtist?> getFollowedArtist(String artistId) =>
      (select(db.followedArtists)
        ..where((t) => t.artistId.equals(artistId))).getSingleOrNull();

  Future<void> insertFollowedArtist(FollowedArtistsCompanion entry) =>
      into(db.followedArtists).insertOnConflictUpdate(entry);

  Future<void> deleteFollowedArtist(String artistId) =>
      (delete(db.followedArtists)
        ..where((t) => t.artistId.equals(artistId))).go();

  // ── Liked Albums ─────────────────────────────────────────────

  Future<List<LikedAlbum>> getAllLikedAlbums() => select(db.likedAlbums).get();

  Future<LikedAlbum?> getLikedAlbum(String albumId) =>
      (select(db.likedAlbums)
        ..where((t) => t.albumId.equals(albumId))).getSingleOrNull();

  Future<void> insertLikedAlbum(LikedAlbumsCompanion entry) =>
      into(db.likedAlbums).insertOnConflictUpdate(entry);

  Future<void> deleteLikedAlbum(String albumId) =>
      (delete(db.likedAlbums)..where((t) => t.albumId.equals(albumId))).go();

  // ── Liked Playlists ──────────────────────────────────────────

  Future<List<LikedPlaylist>> getAllLikedPlaylists() =>
      select(db.likedPlaylists).get();

  Future<LikedPlaylist?> getLikedPlaylist(String playlistId) =>
      (select(db.likedPlaylists)
        ..where((t) => t.playlistId.equals(playlistId))).getSingleOrNull();

  Future<void> insertLikedPlaylist(LikedPlaylistsCompanion entry) =>
      into(db.likedPlaylists).insertOnConflictUpdate(entry);

  Future<void> deleteLikedPlaylist(String playlistId) =>
      (delete(db.likedPlaylists)
        ..where((t) => t.playlistId.equals(playlistId))).go();

  Future<void> updateLikedPlaylistThumbnail(
    String playlistId,
    String thumbnailUrl,
  ) =>
      (update(db.likedPlaylists)
        ..where((t) => t.playlistId.equals(playlistId)))
          .write(LikedPlaylistsCompanion(thumbnailUrl: Value(thumbnailUrl)));
}

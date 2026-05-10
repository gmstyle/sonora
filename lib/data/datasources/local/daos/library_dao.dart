import 'package:drift/drift.dart';
import '../database.dart';

class LibraryDao extends DatabaseAccessor<AppDatabase> {
  LibraryDao(super.db);

  Future<List<LikedSong>> getAllLikedSongs() => select(db.likedSongs).get();

  Future<LikedSong?> getLikedSong(String videoId) =>
      (select(db.likedSongs)..where((t) => t.videoId.equals(videoId)))
          .getSingleOrNull();

  Future<void> insertLikedSong(LikedSongsCompanion entry) =>
      into(db.likedSongs).insertOnConflictUpdate(entry);

  Future<void> deleteLikedSong(String videoId) =>
      (delete(db.likedSongs)..where((t) => t.videoId.equals(videoId))).go();

  Future<List<FollowedArtist>> getAllFollowedArtists() =>
      select(db.followedArtists).get();

  Future<FollowedArtist?> getFollowedArtist(String artistId) =>
      (select(db.followedArtists)..where((t) => t.artistId.equals(artistId)))
          .getSingleOrNull();

  Future<void> insertFollowedArtist(FollowedArtistsCompanion entry) =>
      into(db.followedArtists).insertOnConflictUpdate(entry);

  Future<void> deleteFollowedArtist(String artistId) =>
      (delete(db.followedArtists)..where((t) => t.artistId.equals(artistId)))
          .go();
}

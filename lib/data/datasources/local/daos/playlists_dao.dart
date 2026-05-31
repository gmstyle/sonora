import 'package:drift/drift.dart';
import '../database.dart';

class PlaylistsDao extends DatabaseAccessor<AppDatabase> {
  PlaylistsDao(super.db);

  Future<List<LocalPlaylist>> getAllPlaylists() =>
      select(db.localPlaylists).get();

  Future<LocalPlaylist?> getPlaylist(int id) =>
      (select(db.localPlaylists)
        ..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> createPlaylist(String name, {String? description}) =>
      into(db.localPlaylists).insert(
        LocalPlaylistsCompanion(
          name: Value(name),
          description: Value(description),
          createdAt: Value(DateTime.now()),
        ),
      );

  Future<int> createPlaylistWithDate(
    String name, {
    String? description,
    required DateTime createdAt,
  }) => into(db.localPlaylists).insert(
    LocalPlaylistsCompanion(
      name: Value(name),
      description: Value(description),
      createdAt: Value(createdAt),
    ),
  );

  Future<void> updatePlaylist(int id, {String? name, String? description}) =>
      (update(db.localPlaylists)..where((t) => t.id.equals(id))).write(
        LocalPlaylistsCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          description:
              description != null ? Value(description) : const Value.absent(),
        ),
      );

  Future<void> deletePlaylist(int id) async {
    await (delete(db.playlistEntries)
      ..where((t) => t.playlistId.equals(id))).go();
    await (delete(db.localPlaylists)..where((t) => t.id.equals(id))).go();
  }

  Future<List<PlaylistEntry>> getPlaylistEntries(int playlistId) =>
      (select(db.playlistEntries)
            ..where((t) => t.playlistId.equals(playlistId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();

  Future<void> addEntry(
    int playlistId,
    String videoId,
    int position, {
    String? title,
    String? artist,
    String? thumbnailUrl,
  }) => into(db.playlistEntries).insert(
    PlaylistEntriesCompanion(
      playlistId: Value(playlistId),
      videoId: Value(videoId),
      position: Value(position),
      title: Value(title),
      artist: Value(artist),
      thumbnailUrl: Value(thumbnailUrl),
    ),
  );

  Future<void> removeEntry(int playlistId, String videoId) =>
      (delete(db.playlistEntries)..where(
        (t) => t.playlistId.equals(playlistId) & t.videoId.equals(videoId),
      )).go();

  Future<void> reorderEntries(int playlistId, List<String> videoIds) async {
    for (var i = 0; i < videoIds.length; i++) {
      await (update(db.playlistEntries)..where(
        (t) => t.playlistId.equals(playlistId) & t.videoId.equals(videoIds[i]),
      )).write(PlaylistEntriesCompanion(position: Value(i)));
    }
  }
}

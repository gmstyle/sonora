import 'package:drift/drift.dart';
import '../database.dart';

class PlaylistsDao extends DatabaseAccessor<AppDatabase> {
  PlaylistsDao(super.db);

  Future<List<LocalPlaylist>> getAllPlaylists() =>
      select(db.localPlaylists).get();

  Stream<List<LocalPlaylist>> watchAllPlaylists() =>
      select(db.localPlaylists).watch();

  Future<LocalPlaylist?> getPlaylist(int id) =>
      (select(db.localPlaylists)
        ..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<LocalPlaylist?> findLinkedPlaylist(
    String sourceKind,
    String remoteId,
  ) =>
      (select(db.localPlaylists)..where(
        (t) =>
            t.sourceKind.equals(sourceKind) &
            t.remoteId.equals(remoteId) &
            t.linkStatus.equals('linked'),
      )).getSingleOrNull();

  Future<int> createPlaylist(
    String name, {
    String? description,
    String? sourceKind,
    String? remoteId,
    String? remoteName,
    String linkStatus = 'local',
    DateTime? lastSyncedAt,
  }) => into(db.localPlaylists).insert(
    LocalPlaylistsCompanion(
      name: Value(name),
      description: Value(description),
      createdAt: Value(DateTime.now()),
      sourceKind: Value(sourceKind),
      remoteId: Value(remoteId),
      remoteName: Value(remoteName),
      linkStatus: Value(linkStatus),
      lastSyncedAt: Value(lastSyncedAt),
    ),
  );

  Future<int> createPlaylistWithDate(
    String name, {
    String? description,
    required DateTime createdAt,
    String? sourceKind,
    String? remoteId,
    String? remoteName,
    String linkStatus = 'local',
    DateTime? lastSyncedAt,
  }) => into(db.localPlaylists).insert(
    LocalPlaylistsCompanion(
      name: Value(name),
      description: Value(description),
      createdAt: Value(createdAt),
      sourceKind: Value(sourceKind),
      remoteId: Value(remoteId),
      remoteName: Value(remoteName),
      linkStatus: Value(linkStatus),
      lastSyncedAt: Value(lastSyncedAt),
    ),
  );

  Future<void> updatePlaylist(
    int id, {
    String? name,
    String? description,
    String? sourceKind,
    String? remoteId,
    String? remoteName,
    String? linkStatus,
    DateTime? lastSyncedAt,
    bool clearLink = false,
  }) {
    if (clearLink) {
      return (update(db.localPlaylists)..where((t) => t.id.equals(id))).write(
        LocalPlaylistsCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          description:
              description != null ? Value(description) : const Value.absent(),
          sourceKind: const Value(null),
          remoteId: const Value(null),
          remoteName: const Value(null),
          lastSyncedAt: const Value(null),
          linkStatus: const Value('unlinked'),
        ),
      );
    }
    return (update(db.localPlaylists)..where((t) => t.id.equals(id))).write(
      LocalPlaylistsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        description:
            description != null ? Value(description) : const Value.absent(),
        sourceKind:
            sourceKind != null ? Value(sourceKind) : const Value.absent(),
        remoteId: remoteId != null ? Value(remoteId) : const Value.absent(),
        remoteName:
            remoteName != null ? Value(remoteName) : const Value.absent(),
        linkStatus:
            linkStatus != null ? Value(linkStatus) : const Value.absent(),
        lastSyncedAt:
            lastSyncedAt != null ? Value(lastSyncedAt) : const Value.absent(),
      ),
    );
  }

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

  Stream<List<PlaylistEntry>> watchPlaylistEntries(int playlistId) =>
      (select(db.playlistEntries)
            ..where((t) => t.playlistId.equals(playlistId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch();

  Future<void> addEntry(
    int playlistId,
    String videoId,
    int position, {
    String? title,
    String? artist,
    String? artistsJson,
    String? thumbnailUrl,
    int? duration,
    bool isVideo = false,
    bool isExplicit = false,
  }) => into(db.playlistEntries).insert(
    PlaylistEntriesCompanion(
      playlistId: Value(playlistId),
      videoId: Value(videoId),
      position: Value(position),
      title: Value(title),
      artist: Value(artist),
      artistsJson: Value(artistsJson),
      thumbnailUrl: Value(thumbnailUrl),
      isVideo: Value(isVideo),
      duration: Value(duration),
      isExplicit: Value(isExplicit),
    ),
  );

  /// Atomically replace all entries for [playlistId] with [entries]
  /// (positions taken from list order).
  Future<void> replacePlaylistEntries(
    int playlistId,
    List<
      ({
        String videoId,
        String? title,
        String? artist,
        String? artistsJson,
        String? thumbnailUrl,
        int? duration,
        bool isVideo,
        bool isExplicit,
      })
    >
    entries,
  ) {
    return db.transaction(() async {
      await (delete(db.playlistEntries)
        ..where((t) => t.playlistId.equals(playlistId))).go();
      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        await into(db.playlistEntries).insert(
          PlaylistEntriesCompanion(
            playlistId: Value(playlistId),
            videoId: Value(e.videoId),
            position: Value(i),
            title: Value(e.title),
            artist: Value(e.artist),
            artistsJson: Value(e.artistsJson),
            thumbnailUrl: Value(e.thumbnailUrl),
            isVideo: Value(e.isVideo),
            duration: Value(e.duration),
            isExplicit: Value(e.isExplicit),
          ),
        );
      }
    });
  }

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

  // ── Spotify match cache ──────────────────────────────────────────

  Future<SpotifyMatchCacheData?> getCachedSpotifyMatch(String uri) =>
      (select(db.spotifyMatchCache)
        ..where((t) => t.spotifyTrackUri.equals(uri))).getSingleOrNull();

  Future<void> upsertSpotifyMatch({
    required String spotifyTrackUri,
    required String videoId,
    String? title,
    double? score,
  }) => into(db.spotifyMatchCache).insertOnConflictUpdate(
    SpotifyMatchCacheCompanion(
      spotifyTrackUri: Value(spotifyTrackUri),
      videoId: Value(videoId),
      title: Value(title),
      matchedAt: Value(DateTime.now()),
      score: Value(score),
    ),
  );
}

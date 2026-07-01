import 'package:drift/drift.dart';

import 'tables/liked_songs_table.dart';
import 'tables/followed_artists_table.dart';
import 'tables/liked_albums_table.dart';
import 'tables/liked_playlists_table.dart';
import 'tables/local_playlists_table.dart';
import 'tables/playlist_entries_table.dart';
import 'tables/downloads_table.dart';
import 'tables/history_table.dart';
import 'tables/search_history_table.dart';
import 'tables/queue_items_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    LikedSongs,
    FollowedArtists,
    LikedAlbums,
    LikedPlaylists,
    LocalPlaylists,
    PlaylistEntries,
    Downloads,
    History,
    SearchHistory,
    QueueItems,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(queueItems);
      }
      if (from < 3) {
        final tableInfo =
            await customSelect('PRAGMA table_info(queue_items)').get();
        final hasStreamUrl = tableInfo.any(
          (row) => row.read<String>('name') == 'stream_url',
        );
        if (!hasStreamUrl) {
          await m.addColumn(queueItems, queueItems.streamUrl);
        }
      }
      if (from < 4) {
        await m.addColumn(history, history.thumbnailUrl);
      }
      if (from < 5) {
        await m.addColumn(downloads, downloads.title);
        await m.addColumn(downloads, downloads.artist);
      }
      if (from < 6) {
        await m.addColumn(downloads, downloads.thumbnailUrl);
      }
      if (from < 7) {
        await m.createTable(likedAlbums);
        await m.createTable(likedPlaylists);
      }
      if (from < 8) {
        await m.addColumn(likedSongs, likedSongs.artistId);
        await m.addColumn(likedSongs, likedSongs.albumId);
      }
      if (from < 9) {
        await m.addColumn(playlistEntries, playlistEntries.title);
        await m.addColumn(playlistEntries, playlistEntries.artist);
        await m.addColumn(playlistEntries, playlistEntries.thumbnailUrl);
      }
      if (from < 10) {
        await m.addColumn(queueItems, queueItems.artistId);
        await m.addColumn(queueItems, queueItems.albumId);
      }
      if (from < 11) {
        final historyInfo =
            await customSelect('PRAGMA table_info(history)').get();
        final hasHistoryIsVideo = historyInfo.any(
          (row) => row.read<String>('name') == 'is_video',
        );
        if (!hasHistoryIsVideo) {
          await m.addColumn(history, history.isVideo);
        }

        final downloadsInfo =
            await customSelect('PRAGMA table_info(downloads)').get();
        final hasDownloadsIsVideo = downloadsInfo.any(
          (row) => row.read<String>('name') == 'is_video',
        );
        if (!hasDownloadsIsVideo) {
          await m.addColumn(downloads, downloads.isVideo);
        }
      }
      if (from < 12) {
        final likedSongsInfo =
            await customSelect('PRAGMA table_info(liked_songs)').get();
        final hasLikedSongsIsVideo = likedSongsInfo.any(
          (row) => row.read<String>('name') == 'is_video',
        );
        if (!hasLikedSongsIsVideo) {
          await m.addColumn(likedSongs, likedSongs.isVideo);
        }

        final playlistEntriesInfo =
            await customSelect('PRAGMA table_info(playlist_entries)').get();
        final hasPlaylistEntriesIsVideo = playlistEntriesInfo.any(
          (row) => row.read<String>('name') == 'is_video',
        );
        if (!hasPlaylistEntriesIsVideo) {
          await m.addColumn(playlistEntries, playlistEntries.isVideo);
        }
      }
      if (from < 13) {
        final followedArtistsInfo =
            await customSelect('PRAGMA table_info(followed_artists)').get();
        final hasFollowedArtistsAddedAt = followedArtistsInfo.any(
          (row) => row.read<String>('name') == 'added_at',
        );
        if (!hasFollowedArtistsAddedAt) {
          await m.alterTable(
            TableMigration(
              followedArtists,
              columnTransformer: {followedArtists.addedAt: currentDateAndTime},
            ),
          );
        }
      }
      if (from < 14) {
        final likedSongsInfo =
            await customSelect('PRAGMA table_info(liked_songs)').get();
        final hasLikedSongsDuration = likedSongsInfo.any(
          (row) => row.read<String>('name') == 'duration',
        );
        if (!hasLikedSongsDuration) {
          await m.addColumn(likedSongs, likedSongs.duration);
        }

        final historyInfo =
            await customSelect('PRAGMA table_info(history)').get();
        final hasHistoryDuration = historyInfo.any(
          (row) => row.read<String>('name') == 'duration',
        );
        if (!hasHistoryDuration) {
          await m.addColumn(history, history.duration);
        }
      }
      if (from < 15) {
        await m.addColumn(likedSongs, likedSongs.isExplicit);
        await m.addColumn(history, history.isExplicit);
        await m.addColumn(downloads, downloads.isExplicit);
        await m.addColumn(playlistEntries, playlistEntries.isExplicit);
        await m.addColumn(queueItems, queueItems.isExplicit);
      }
      if (from < 16) {
        final playlistEntriesInfo =
            await customSelect('PRAGMA table_info(playlist_entries)').get();
        final hasPlaylistEntriesDuration = playlistEntriesInfo.any(
          (row) => row.read<String>('name') == 'duration',
        );
        if (!hasPlaylistEntriesDuration) {
          await m.addColumn(playlistEntries, playlistEntries.duration);
        }
      }
    },
  );

  Future<void> updateSongMetadata(
    String videoId,
    int duration,
    bool isExplicit,
  ) async {
    await transaction(() async {
      await (update(likedSongs)..where((t) => t.videoId.equals(videoId))).write(
        LikedSongsCompanion(
          duration: Value(duration),
          isExplicit: Value(isExplicit),
        ),
      );
      await (update(history)..where((t) => t.videoId.equals(videoId))).write(
        HistoryCompanion(
          duration: Value(duration),
          isExplicit: Value(isExplicit),
        ),
      );
      await (update(playlistEntries)
        ..where((t) => t.videoId.equals(videoId))).write(
        PlaylistEntriesCompanion(
          duration: Value(duration),
          isExplicit: Value(isExplicit),
        ),
      );
    });
  }

  Future<List<String>> getTrackIdsMissingMetadata({int limit = 15}) async {
    final liked =
        await (select(likedSongs)
              ..where((t) => t.duration.isNull())
              ..limit(limit))
            .get();
    final likedIds = liked.map((e) => e.videoId).toList();
    if (likedIds.length >= limit) return likedIds;

    final hist =
        await (select(history)
              ..where((t) => t.duration.isNull())
              ..limit(limit - likedIds.length))
            .get();
    final histIds = hist.map((e) => e.videoId).toList();
    final combined = {...likedIds, ...histIds};
    if (combined.length >= limit) return combined.toList();

    final pl =
        await (select(playlistEntries)
              ..where((t) => t.duration.isNull())
              ..limit(limit - combined.length))
            .get();
    final plIds = pl.map((e) => e.videoId).toList();
    combined.addAll(plIds);
    return combined.toList();
  }

  Future<int> getTrackCountMissingMetadata() async {
    final liked =
        await customSelect(
          'SELECT COUNT(*) as c FROM liked_songs WHERE duration IS NULL',
        ).getSingle();
    final history =
        await customSelect(
          'SELECT COUNT(*) as c FROM history WHERE duration IS NULL',
        ).getSingle();
    final playlist =
        await customSelect(
          'SELECT COUNT(*) as c FROM playlist_entries WHERE duration IS NULL',
        ).getSingle();
    return liked.read<int>('c') +
        history.read<int>('c') +
        playlist.read<int>('c');
  }
}

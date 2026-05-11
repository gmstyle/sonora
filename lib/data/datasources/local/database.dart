import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tables/liked_songs_table.dart';
import 'tables/followed_artists_table.dart';
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

  AppDatabase._() : super(_openConnection());

  static AppDatabase create() => AppDatabase._();

  @override
  int get schemaVersion => 3;

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
    },
  );
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'sonora',
    native: const DriftNativeOptions(
      databaseDirectory: getApplicationDocumentsDirectory,
    ),
  );
}

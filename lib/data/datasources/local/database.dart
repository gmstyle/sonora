import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/liked_songs_table.dart';
import 'tables/followed_artists_table.dart';
import 'tables/local_playlists_table.dart';
import 'tables/playlist_entries_table.dart';
import 'tables/downloads_table.dart';
import 'tables/history_table.dart';
import 'tables/search_history_table.dart';

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
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase._() : super(_openConnection());

  static AppDatabase create() => AppDatabase._();

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'sonora.sqlite'));
    return NativeDatabase(file);
  });
}

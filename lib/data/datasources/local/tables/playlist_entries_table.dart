import 'package:drift/drift.dart';
import 'local_playlists_table.dart';

class PlaylistEntries extends Table {
  IntColumn get playlistId => integer().references(LocalPlaylists, #id)();
  TextColumn get videoId => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {playlistId, videoId};
}

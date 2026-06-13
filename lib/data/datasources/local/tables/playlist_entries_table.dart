import 'package:drift/drift.dart';
import 'local_playlists_table.dart';

class PlaylistEntries extends Table {
  IntColumn get playlistId => integer().references(LocalPlaylists, #id)();
  TextColumn get videoId => text()();
  IntColumn get position => integer()();
  TextColumn? get title => text().nullable()();
  TextColumn? get artist => text().nullable()();
  TextColumn? get thumbnailUrl => text().nullable()();
  BoolColumn get isVideo => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {playlistId, videoId};
}

import 'package:drift/drift.dart';

class Downloads extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text().nullable()();
  TextColumn get artist => text().nullable()();

  /// JSON array of credited artists when length > 1; null for single-artist rows.
  TextColumn get artistsJson => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  TextColumn get localPath => text().nullable()();
  TextColumn get format => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  DateTimeColumn get downloadedAt => dateTime().nullable()();
  TextColumn get status => text()();
  BoolColumn get isVideo => boolean().withDefault(const Constant(false))();
  BoolColumn get isExplicit => boolean().withDefault(const Constant(false))();

  /// Stable collection id (album/playlist/podcast/local playlist), without type prefix.
  TextColumn get collectionId => text().nullable()();

  /// `album` | `playlist` | `podcast` | `localPlaylist`
  TextColumn get collectionType => text().nullable()();

  TextColumn get collectionName => text().nullable()();

  /// Position in the source album/playlist/podcast list (0-based). Null for singles.
  IntColumn get collectionIndex => integer().nullable()();

  @override
  Set<Column> get primaryKey => {videoId};
}

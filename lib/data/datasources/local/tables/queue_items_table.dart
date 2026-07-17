import 'package:drift/drift.dart';

class QueueItems extends Table {
  IntColumn get position => integer()();
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get artist => text()();
  TextColumn get albumTitle => text().nullable()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get durationSec => integer().nullable()();
  BoolColumn get isVideo => boolean()();
  TextColumn get streamUrl => text().nullable()();
  TextColumn get artistId => text().nullable()();
  TextColumn get albumId => text().nullable()();
  BoolColumn get isExplicit => boolean().withDefault(const Constant(false))();

  /// Queue section this item belongs to: `'user'` or `'upnext'`.
  /// Defaults to `'user'` for legacy rows written before the queue split.
  TextColumn get section => text().withDefault(const Constant('user'))();

  @override
  Set<Column> get primaryKey => {position};
}

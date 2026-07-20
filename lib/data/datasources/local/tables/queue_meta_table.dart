import 'package:drift/drift.dart';

/// Single-row table holding the "where were we" pointer for the persisted
/// playback queue: current index, the stable videoId anchor for that index,
/// last known position, and shuffle/repeat mode.
///
/// This used to be split across [SharedPreferences] (index/position/modes)
/// and the [QueueItems] table (the queue itself), written by independent,
/// unawaited fire-and-forget calls. That split made it possible for the
/// queue on disk and the "current index" pointer to go out of sync (e.g. the
/// process dies right after an autoplay append whose queue write hadn't
/// landed yet, while the index write already had) — silently resuming into
/// the wrong track on next launch.
///
/// By keeping this pointer in the *same* Drift database as [QueueItems] and
/// writing both inside a single transaction (see
/// `QueueRepositoryImpl.persistQueue`), the two can never disagree: either
/// both writes land, or neither does.
///
/// Always exactly one row exists, with [id] pinned to 0.
class QueueMeta extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  IntColumn get currentIndex => integer().withDefault(const Constant(0))();
  TextColumn get currentVideoId => text().nullable()();
  IntColumn get positionMs => integer().withDefault(const Constant(0))();
  TextColumn get shuffleMode => text().nullable()();
  TextColumn get repeatMode => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

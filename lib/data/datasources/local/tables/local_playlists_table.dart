import 'package:drift/drift.dart';

class LocalPlaylists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// `youtube` | `spotify`, or null for pure local / unlinked.
  TextColumn get sourceKind => text().nullable()();

  /// Remote playlist id on Spotify or YouTube.
  TextColumn get remoteId => text().nullable()();

  /// Last remote name seen at sync/import (rename policy).
  TextColumn get remoteName => text().nullable()();

  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  /// `local` | `linked` | `unlinked`
  TextColumn get linkStatus => text().withDefault(const Constant('local'))();
}

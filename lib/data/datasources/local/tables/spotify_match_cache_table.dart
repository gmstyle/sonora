import 'package:drift/drift.dart';

/// Persists Spotify track URI → YouTube Music videoId matches across syncs.
class SpotifyMatchCache extends Table {
  TextColumn get spotifyTrackUri => text()();
  TextColumn get videoId => text()();
  TextColumn get title => text().nullable()();
  DateTimeColumn get matchedAt => dateTime()();
  RealColumn get score => real().nullable()();

  @override
  Set<Column> get primaryKey => {spotifyTrackUri};
}

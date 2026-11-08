import 'package:drift/drift.dart';

/// One row per normalized search query ([queryKey]).
@TableIndex(
  name: 'idx_search_history_query_key',
  columns: {#queryKey},
  unique: true,
)
class SearchHistory extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Display text from the last submit (preserves the user's casing).
  TextColumn get query => text()();

  /// Trimmed, lowercased [query] used for uniqueness and deletes.
  /// Default '' lets schema v26 add the column before the backfill.
  TextColumn get queryKey => text().withDefault(const Constant(''))();

  DateTimeColumn get searchedAt => dateTime()();
}

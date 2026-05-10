import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/daos/downloads_dao.dart';
import '../../data/datasources/local/daos/history_dao.dart';
import '../../data/datasources/local/daos/library_dao.dart';
import '../../data/datasources/local/daos/playlists_dao.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../domain/repositories/library_repository.dart';
import 'database_provider.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return LibraryRepositoryImpl(
    LibraryDao(db),
    PlaylistsDao(db),
    DownloadsDao(db),
    HistoryDao(db),
  );
});

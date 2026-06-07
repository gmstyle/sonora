import 'dart:io';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

import '../data/datasources/local/database.dart';
import '../data/datasources/local/daos/downloads_dao.dart';
import '../data/datasources/local/daos/history_dao.dart';
import '../data/datasources/local/daos/library_dao.dart';
import '../data/datasources/local/daos/playlists_dao.dart';
import '../data/datasources/remote/stream_datasource.dart';
import '../data/datasources/remote/ytmusic_datasource.dart';
import '../data/repositories/library_repository_impl.dart';
import '../data/repositories/music_repository_impl.dart';
import '../domain/repositories/library_repository.dart';
import '../domain/repositories/music_repository.dart';

class SonoraCliProvider {
  late final YtmusicDatasource ytmusicDs;
  late final StreamDatasource streamDs;
  late final AppDatabase database;
  late final MusicRepository musicRepo;
  late final LibraryRepository libraryRepo;
  late final Dio dio;

  Future<void> initialize() async {
    await YTMusic().initialize();

    ytmusicDs = YtmusicDatasource();
    await ytmusicDs.initialize();

    streamDs = StreamDatasource();

    final dbPath = _dbPath();
    final dbDir = Directory(p.dirname(dbPath));
    if (!dbDir.existsSync()) dbDir.createSync(recursive: true);
    database = AppDatabase(NativeDatabase(File(dbPath)));

    final libraryDao = LibraryDao(database);
    final playlistsDao = PlaylistsDao(database);
    final downloadsDao = DownloadsDao(database);
    final historyDao = HistoryDao(database);

    libraryRepo = LibraryRepositoryImpl(
      libraryDao,
      playlistsDao,
      downloadsDao,
      historyDao,
    );
    musicRepo = MusicRepositoryImpl(ytmusicDs, streamDs);
    dio = Dio();
  }

  Future<void> dispose() async {
    streamDs.dispose();
    await database.close();
  }

  String _dbPath() {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return p.join(home, '.local', 'share', 'sonora', 'sonora.sqlite');
  }
}

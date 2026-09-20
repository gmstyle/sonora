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
  SonoraCliProvider({String? databasePath}) : _databasePath = databasePath;

  final String? _databasePath;

  YtmusicDatasource? _ytmusicDs;
  StreamDatasource? _streamDs;
  AppDatabase? _database;
  MusicRepository? _musicRepo;
  LibraryRepository? _libraryRepo;
  Dio? _dio;
  bool _localReady = false;
  bool _remoteReady = false;

  bool get isLocalReady => _localReady;
  bool get isRemoteReady => _remoteReady;

  YtmusicDatasource get ytmusicDs => _require(_ytmusicDs, remote: true);
  StreamDatasource get streamDs => _require(_streamDs, remote: true);
  AppDatabase get database => _require(_database);
  MusicRepository get musicRepo => _require(_musicRepo, remote: true);
  LibraryRepository get libraryRepo => _require(_libraryRepo);
  Dio get dio => _require(_dio, remote: true);

  /// Opens the shared SQLite store. No Innertube / YouTube Music contact.
  Future<void> initializeLocal() async {
    if (_localReady) return;

    final dbPath = _databasePath ?? _defaultDbPath();
    final dbDir = Directory(p.dirname(dbPath));
    if (!dbDir.existsSync()) dbDir.createSync(recursive: true);
    _database = AppDatabase(NativeDatabase(File(dbPath)));

    _libraryRepo = LibraryRepositoryImpl(
      LibraryDao(_database!),
      PlaylistsDao(_database!),
      DownloadsDao(_database!),
      HistoryDao(_database!),
    );
    _localReady = true;
  }

  /// Connects YouTube Music (Innertube) and stream/download clients.
  Future<void> initializeRemote() async {
    await initializeLocal();
    if (_remoteReady) return;

    await YTMusic().initialize();
    _ytmusicDs = YtmusicDatasource();
    await _ytmusicDs!.initialize();
    _streamDs = StreamDatasource();
    _musicRepo = MusicRepositoryImpl(_ytmusicDs!, _streamDs!);
    _dio = Dio();
    _remoteReady = true;
  }

  /// Full init for commands that always need Innertube (`search`, `download`).
  Future<void> initialize() => initializeRemote();

  Future<void> dispose() async {
    _streamDs?.dispose();
    await _database?.close();
  }

  T _require<T>(T? value, {bool remote = false}) {
    if (value != null) return value;
    throw StateError(
      remote
          ? 'CLI remote services are not initialized.'
          : 'CLI local store is not initialized.',
    );
  }

  String _defaultDbPath() {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return p.join(home, '.local', 'share', 'sonora', 'sonora.sqlite');
  }
}

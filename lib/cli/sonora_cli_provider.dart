import 'dart:io';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:youtube_explode_dart/js_challenge.dart';
import 'package:youtube_explode_dart/solvers.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../data/datasources/local/database.dart';
import '../data/datasources/local/daos/downloads_dao.dart';
import '../data/datasources/local/daos/history_dao.dart';
import '../data/datasources/local/daos/library_dao.dart';
import '../data/datasources/local/daos/playlists_dao.dart';
import '../data/datasources/remote/stream_datasource.dart';
import '../data/datasources/remote/ytm_session_http_client.dart';
import '../data/datasources/remote/ytmusic_datasource.dart';
import '../data/repositories/library_repository_impl.dart';
import '../data/repositories/music_repository_impl.dart';
import '../data/services/youtube_session_store.dart';
import '../domain/repositories/library_repository.dart';
import '../domain/repositories/music_repository.dart';

class SonoraCliProvider {
  SonoraCliProvider({this._databasePath});

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

    _ytmusicDs = YtmusicDatasource();
    final dbPath = _databasePath ?? _defaultDbPath();
    final sessionDir = p.dirname(dbPath);
    final sessionStore = YoutubeSessionStore.inDirectory(sessionDir);
    _ytmusicDs!.client.onSessionCookiesChanged = () =>
        sessionStore.scheduleSaveFrom(_ytmusicDs!.client);
    await sessionStore.loadInto(YTMusic());
    await _ytmusicDs!.initialize();
    await sessionStore.saveFrom(YTMusic());
    final httpClient = YoutubeHttpClient(
      YtmSessionHttpClient(ytmusic: _ytmusicDs!.client),
    );
    final jsRunner = Platform.isLinux
        ? await ChromiumCdpJsRunner.tryCreate()
        : null;
    final poTokenProvider = jsRunner != null
        ? BotGuardPoTokenProvider(
            runner: jsRunner,
            httpClient: httpClient,
            visitorDataProvider: () =>
                _ytmusicDs!.client.config['VISITOR_DATA'],
            sessionKeyProvider: () =>
                _ytmusicDs!.client.config['USER_SESSION_ID'] ??
                _ytmusicDs!.client.config['DATASYNC_ID'] ??
                '',
          )
        : null;
    final jsSolver = jsRunner != null
        ? RunnerEJSSolver(runner: jsRunner)
        : null;
    _streamDs = StreamDatasource(
      httpClient: httpClient,
      poTokenProvider: poTokenProvider,
      jsSolver: jsSolver,
      onDispose: jsRunner?.dispose,
    );
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

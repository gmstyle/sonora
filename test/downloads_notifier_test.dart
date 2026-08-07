import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/core/constants/app_constants.dart';
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/data/datasources/local/daos/downloads_dao.dart';
import 'package:sonora/data/datasources/local/daos/history_dao.dart';
import 'package:sonora/data/datasources/local/daos/library_dao.dart';
import 'package:sonora/data/datasources/local/daos/playlists_dao.dart';
import 'package:sonora/data/datasources/remote/stream_datasource.dart';
import 'package:sonora/data/repositories/library_repository_impl.dart';
import 'package:sonora/domain/models/media_quality.dart';
import 'package:sonora/domain/repositories/library_repository.dart';
import 'package:sonora/domain/usecases/download/download_exceptions.dart';
import 'package:sonora/domain/usecases/download/start_download_use_case.dart';
import 'package:sonora/presentation/providers/download_provider.dart';
import 'package:sonora/presentation/providers/library_repository_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';
import 'package:sonora/presentation/providers/start_download_use_case_provider.dart';

class _FakeStartDownloadUseCase extends StartDownloadUseCase {
  _FakeStartDownloadUseCase(LibraryRepository repository)
    : super(StreamDatasource(), Dio(), repository);

  final List<String> started = [];
  final Set<String> failIds = {};
  final Map<String, Completer<void>> _gates = {};

  Completer<void> gateFor(String videoId) =>
      _gates.putIfAbsent(videoId, Completer<void>.new);

  @override
  Future<String> execute({
    required String videoId,
    required String title,
    required String artist,
    String? thumbnailUrl,
    bool downloadOnlyOnWifi = false,
    String? downloadPath,
    String? subdirectory,
    bool isVideo = false,
    bool isExplicit = false,
    MediaQuality quality = MediaQuality.high,
    CancelToken? cancelToken,
    required void Function(int received, int total) onProgress,
  }) async {
    started.add(videoId);
    if (failIds.contains(videoId)) {
      throw const DownloadWifiRestrictionException();
    }

    final gate = _gates.putIfAbsent(videoId, Completer<void>.new);
    final cancelFuture = cancelToken?.whenCancel;
    if (cancelFuture != null) {
      await Future.any([gate.future, cancelFuture]);
    } else {
      await gate.future;
    }
    if (cancelToken?.isCancelled ?? false) {
      throw const DownloadCancelledException();
    }
    return '/tmp/$videoId.mp4';
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late _FakeStartDownloadUseCase fakeUseCase;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    db = AppDatabase(NativeDatabase.memory());
    final repo = LibraryRepositoryImpl(
      LibraryDao(db),
      PlaylistsDao(db),
      DownloadsDao(db),
      HistoryDao(db),
    );
    fakeUseCase = _FakeStartDownloadUseCase(repo);

    container = ProviderContainer(
      overrides: [
        startDownloadUseCaseProvider.overrideWithValue(fakeUseCase),
        libraryRepositoryProvider.overrideWithValue(repo),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Map<String, ActiveDownload> state() =>
      container.read(activeDownloadsProvider);

  Future<void> enqueue(String videoId) {
    return container
        .read(activeDownloadsProvider.notifier)
        .startDownload(
          videoId: videoId,
          title: 'Title $videoId',
          artist: 'Artist $videoId',
        );
  }

  group('DownloadsNotifier queue', () {
    test('runs at most kMaxConcurrentDownloads and queues the rest', () async {
      for (var i = 0; i < 5; i++) {
        unawaited(enqueue('v$i'));
      }

      final downloads = state();
      expect(downloads.length, 5);
      expect(
        downloads.values
            .where((d) => d.status == DownloadStatus.downloading)
            .length,
        kMaxConcurrentDownloads,
      );
      expect(
        downloads.values
            .where((d) => d.status == DownloadStatus.pending)
            .length,
        5 - kMaxConcurrentDownloads,
      );
      expect(fakeUseCase.started, ['v0', 'v1', 'v2']);
    });

    test('promotes oldest pending when a slot frees up', () async {
      final futures = <String, Future<void>>{
        for (var i = 0; i < 4; i++) 'v$i': enqueue('v$i'),
      };

      expect(state()['v3']!.status, DownloadStatus.pending);

      fakeUseCase.gateFor('v0').complete();
      await futures['v0'];

      expect(state()['v3']!.status, DownloadStatus.downloading);
      expect(fakeUseCase.started, ['v0', 'v1', 'v2', 'v3']);
    });

    test('startDownload future completes without throwing on error', () async {
      fakeUseCase.failIds.add('v0');

      final future = enqueue('v0');
      await expectLater(future, completes);

      expect(state()['v0']!.status, DownloadStatus.error);
      expect(state()['v0']!.error, DownloadError.wifiRestricted);
    });

    test(
      'cancelDownload on pending item removes it and completes future',
      () async {
        final futures = <String, Future<void>>{
          for (var i = 0; i < 4; i++) 'v$i': enqueue('v$i'),
        };

        await container
            .read(activeDownloadsProvider.notifier)
            .cancelDownload('v3');

        expect(state().containsKey('v3'), isFalse);
        await expectLater(futures['v3'], completes);
      },
    );

    test(
      'cancelDownload on active item frees the slot for the next pending',
      () async {
        final futures = <String, Future<void>>{
          for (var i = 0; i < 4; i++) 'v$i': enqueue('v$i'),
        };

        await container
            .read(activeDownloadsProvider.notifier)
            .cancelDownload('v0');

        expect(state().containsKey('v0'), isFalse);
        expect(state()['v3']!.status, DownloadStatus.downloading);
        await expectLater(futures['v0'], completes);
      },
    );

    test('retry re-enqueues an errored download', () async {
      fakeUseCase.failIds.add('v0');
      await enqueue('v0');
      expect(state()['v0']!.status, DownloadStatus.error);

      fakeUseCase.failIds.remove('v0');
      final retryFuture = container
          .read(activeDownloadsProvider.notifier)
          .retry('v0');

      expect(state()['v0']!.status, DownloadStatus.downloading);

      fakeUseCase.gateFor('v0').complete();
      await retryFuture;
    });
  });
}

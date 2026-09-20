import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sonora/cli/sonora_cli_provider.dart';
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/data/datasources/local/daos/downloads_dao.dart';
import 'package:sonora/data/datasources/local/daos/history_dao.dart';
import 'package:sonora/data/datasources/local/daos/library_dao.dart';
import 'package:sonora/data/datasources/local/daos/playlists_dao.dart';
import 'package:sonora/data/repositories/library_repository_impl.dart';
import 'package:sonora/domain/usecases/player/play_video_id_use_case.dart';

void main() {
  test('initializeLocal opens sqlite without Innertube', () async {
    final dir = await Directory.systemTemp.createTemp('sonora_cli_local_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final provider = SonoraCliProvider(
      databasePath: p.join(dir.path, 'sonora.sqlite'),
    );
    await provider.initializeLocal();
    addTearDown(provider.dispose);

    expect(provider.isLocalReady, isTrue);
    expect(provider.isRemoteReady, isFalse);
    expect(await provider.libraryRepo.getAllDownloads(), isEmpty);
    expect(() => provider.musicRepo, throwsA(isA<StateError>()));
  });

  test(
    'resolveCompletedDownloadUrl returns file URI and skips missing files',
    () async {
      final dir = await Directory.systemTemp.createTemp('sonora_cli_url_');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = LibraryRepositoryImpl(
        LibraryDao(db),
        PlaylistsDao(db),
        DownloadsDao(db),
        HistoryDao(db),
      );

      final file = File(p.join(dir.path, 'Song-vid1.m4a'));
      await file.writeAsString('audio');
      await repo.insertDownload(
        videoId: 'vid1',
        title: 'Song',
        artist: 'Artist',
        status: 'completed',
        localPath: file.path,
      );

      expect(
        await resolveCompletedDownloadUrl('vid1', repo),
        file.uri.toString(),
      );

      await file.delete();
      expect(await resolveCompletedDownloadUrl('vid1', repo), isNull);
      expect(await repo.getDownload('vid1'), isNull);
    },
  );
}

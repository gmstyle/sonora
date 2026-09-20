import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/data/datasources/local/daos/downloads_dao.dart';
import 'package:sonora/data/datasources/local/daos/history_dao.dart';
import 'package:sonora/data/datasources/local/daos/library_dao.dart';
import 'package:sonora/data/datasources/local/daos/playlists_dao.dart';
import 'package:sonora/data/repositories/library_repository_impl.dart';
import 'package:sonora/domain/usecases/download/download_replacement.dart';

void main() {
  late AppDatabase db;
  late LibraryRepositoryImpl repo;
  late Directory dir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LibraryRepositoryImpl(
      LibraryDao(db),
      PlaylistsDao(db),
      DownloadsDao(db),
      HistoryDao(db),
    );
    dir = await Directory.systemTemp.createTemp('sonora_replacement_');
  });

  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<void> seedCompleted({
    required String videoId,
    required String localPath,
  }) {
    return repo.insertDownload(
      videoId: videoId,
      title: 'Song',
      artist: 'Artist',
      status: 'completed',
      localPath: localPath,
      format: 'm4a',
      fileSize: 12,
      downloadedAt: DateTime(2024, 1, 1),
      collectionId: 'album1',
      collectionType: 'album',
      collectionName: 'Album',
    );
  }

  test(
    'promoteOnSuccess deletes the previous file only after the new file is in place',
    () async {
      final oldPath = p.join(dir.path, 'Song-vid1.m4a');
      final newPath = p.join(dir.path, 'Album', 'Song-vid1.m4a');
      await File(oldPath).writeAsString('old');
      await Directory(p.dirname(newPath)).create(recursive: true);
      await File(downloadPartPath(newPath)).writeAsString('new');
      await seedCompleted(videoId: 'vid1', localPath: oldPath);

      final replacement = DownloadReplacement.capture(
        await repo.getDownload('vid1'),
      );
      await replacement.promoteOnSuccess(newPath);

      expect(await File(oldPath).exists(), isFalse);
      expect(await File(newPath).exists(), isTrue);
      expect(await File(newPath).readAsString(), 'new');
      expect(await File(downloadPartPath(newPath)).exists(), isFalse);
    },
  );

  test(
    'failed replacement restores the completed row and keeps the old file',
    () async {
      final oldPath = p.join(dir.path, 'Song-vid1.m4a');
      final newPath = p.join(dir.path, 'Album', 'Song-vid1.m4a');
      await File(oldPath).writeAsString('old');
      await Directory(p.dirname(newPath)).create(recursive: true);
      await File(downloadPartPath(newPath)).writeAsString('partial');
      await seedCompleted(videoId: 'vid1', localPath: oldPath);

      final replacement = DownloadReplacement.capture(
        await repo.getDownload('vid1'),
      );
      await repo.insertDownload(
        videoId: 'vid1',
        title: 'Song',
        artist: 'Artist',
        status: 'downloading',
        localPath: newPath,
        format: 'm4a',
      );
      await replacement.revertOnFailure(
        library: repo,
        videoId: 'vid1',
        newFilePath: newPath,
      );

      expect(await File(oldPath).exists(), isTrue);
      expect(await File(oldPath).readAsString(), 'old');
      expect(await File(downloadPartPath(newPath)).exists(), isFalse);
      expect(await File(newPath).exists(), isFalse);

      final restored = await repo.getDownload('vid1');
      expect(restored, isNotNull);
      expect(restored!.status, 'completed');
      expect(restored.localPath, oldPath);
      expect(restored.collectionName, 'Album');
      expect(restored.fileSize, 12);
    },
  );

  test('failed first-time download deletes the incomplete row', () async {
    final newPath = p.join(dir.path, 'Song-vid2.m4a');
    await File(downloadPartPath(newPath)).writeAsString('partial');

    final replacement = DownloadReplacement.capture(null);
    await repo.insertDownload(
      videoId: 'vid2',
      title: 'Song',
      artist: 'Artist',
      status: 'downloading',
      localPath: newPath,
    );
    await replacement.revertOnFailure(
      library: repo,
      videoId: 'vid2',
      newFilePath: newPath,
    );

    expect(await repo.getDownload('vid2'), isNull);
    expect(await File(downloadPartPath(newPath)).exists(), isFalse);
  });
}

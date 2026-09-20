import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/cli/commands/play_command.dart';
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/data/datasources/local/daos/downloads_dao.dart';
import 'package:sonora/data/datasources/local/daos/history_dao.dart';
import 'package:sonora/data/datasources/local/daos/library_dao.dart';
import 'package:sonora/data/datasources/local/daos/playlists_dao.dart';
import 'package:sonora/data/repositories/library_repository_impl.dart';
import 'package:sonora/domain/repositories/music_repository.dart';

class _RecordingMusicRepo extends Fake implements MusicRepository {
  int getSongCalls = 0;

  @override
  Future<SongFull> getSong(String videoId) {
    getSongCalls++;
    throw StateError('network unavailable');
  }
}

void main() {
  late AppDatabase db;
  late LibraryRepositoryImpl repo;
  late _RecordingMusicRepo musicRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LibraryRepositoryImpl(
      LibraryDao(db),
      PlaylistsDao(db),
      DownloadsDao(db),
      HistoryDao(db),
    );
    musicRepo = _RecordingMusicRepo();
  });

  tearDown(() async {
    await db.close();
  });

  test('uses completed download metadata without calling getSong', () async {
    await repo.insertDownload(
      videoId: 'vid1',
      title: 'Local Song',
      artist: 'Local Artist',
      status: 'completed',
      localPath: '/tmp/Local Song-vid1.m4a',
    );

    final meta = await resolveCliPlayMetadata(
      videoId: 'vid1',
      libraryRepo: repo,
      musicRepo: musicRepo,
    );

    expect(meta.title, 'Local Song');
    expect(meta.artist, 'Local Artist');
    expect(musicRepo.getSongCalls, 0);
  });

  test(
    'falls back to videoId when offline and no completed download',
    () async {
      final meta = await resolveCliPlayMetadata(
        videoId: 'vid2',
        libraryRepo: repo,
        musicRepo: musicRepo,
      );

      expect(meta.title, 'vid2');
      expect(meta.artist, '');
      expect(musicRepo.getSongCalls, 1);
    },
  );
}

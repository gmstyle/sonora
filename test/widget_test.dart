import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/data/datasources/local/daos/downloads_dao.dart';
import 'package:sonora/data/datasources/local/daos/history_dao.dart';
import 'package:sonora/data/datasources/local/daos/library_dao.dart';
import 'package:sonora/data/datasources/local/daos/playlists_dao.dart';
import 'package:sonora/data/datasources/remote/stream_datasource.dart';
import 'package:sonora/data/datasources/remote/ytmusic_datasource.dart';
import 'package:sonora/data/repositories/library_repository_impl.dart';
import 'package:sonora/data/repositories/music_repository_impl.dart';
import 'package:sonora/domain/usecases/player/play_video_id_use_case.dart';
import 'package:sonora/main.dart';
import 'package:sonora/presentation/features/player/audio_handler.dart';
import 'package:sonora/presentation/providers/database_provider.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';

void main() {
  testWidgets('App builds and shows title', (WidgetTester tester) async {
    MediaKit.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final libraryRepo = LibraryRepositoryImpl(
      LibraryDao(db),
      PlaylistsDao(db),
      DownloadsDao(db),
      HistoryDao(db),
    );
    final musicRepo = MusicRepositoryImpl(
      YtmusicDatasource(),
      StreamDatasource(),
    );
    final playVideoIdUseCase = PlayVideoIdUseCase(musicRepo, libraryRepo);

    final handler = SonoraAudioHandler(
      musicRepo: musicRepo,
      libraryRepo: libraryRepo,
      playVideoIdUseCase: playVideoIdUseCase,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const SonoraApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Sonora'), findsAtLeast(1));
  });
}

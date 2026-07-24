import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audio_service/audio_service.dart';

import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/data/repositories/queue_repository_impl.dart';
import 'package:sonora/presentation/features/player/controllers/playback_restore_controller.dart';
import 'package:sonora/presentation/features/player/controllers/queue_controller.dart';
import 'package:sonora/domain/usecases/player/play_video_id_use_case.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';

class MockPlayVideoIdUseCase implements PlayVideoIdUseCase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  late AppDatabase db;
  late QueueRepositoryImpl queueRepo;
  late Player player;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'restoreQueueOnStartup': true,
      kPostQueueSplitDoneKey: true,
    });
    db = AppDatabase(NativeDatabase.memory());
    queueRepo = QueueRepositoryImpl(db);
    player = Player();
  });

  tearDown(() async {
    await player.dispose();
    await db.close();
  });

  test('consumePendingSavedPosition returns saved position on first play and clears flag', () async {
    final prefs = await SharedPreferences.getInstance();
    final queueController = QueueController(
      player: player,
      queueRepo: queueRepo,
      getQueue: () => [],
      getShuffleMode: () => AudioServiceShuffleMode.none,
      getRepeatMode: () => AudioServiceRepeatMode.none,
      updateQueueStream: (_) {},
    );

    final controller = PlaybackRestoreController(
      player: player,
      prefs: prefs,
      queueRepo: queueRepo,
      queueController: queueController,
      playVideoIdUseCase: MockPlayVideoIdUseCase(),
      getResolutionController: () => throw UnimplementedError(),
      updateQueueStream: (_) {},
      setShuffleState: (_) {},
      setRepeatState: (_) {},
      onStateUpdated: () {},
      getLastPauseTimestamp: () => null,
    );

    // Persist a track and a position of 20 seconds in DB
    final item = const MediaItem(
      id: 'v123',
      title: 'Test Track',
      artist: 'Test Artist',
      extras: {'videoId': 'v123'},
    );
    await queueRepo.persistQueue(
      [item],
      currentIndex: 0,
      position: const Duration(seconds: 20),
    );

    // Initial state before restore
    expect(controller.hasPendingSavedPosition, false);
    expect(controller.consumePendingSavedPosition(), isNull);

    // Perform restore
    await controller.restoreQueue();

    // After restore, savedPosition should be 20 seconds and pending flag true
    expect(controller.savedPosition, const Duration(seconds: 20));
    expect(controller.hasPendingSavedPosition, true);

    // First call consumes the position
    final consumed = controller.consumePendingSavedPosition();
    expect(consumed, const Duration(seconds: 20));

    // Subsequent calls return null
    expect(controller.hasPendingSavedPosition, false);
    expect(controller.consumePendingSavedPosition(), isNull);

    controller.dispose();
  });
}

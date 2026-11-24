import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/domain/models/queue_track.dart';
import 'package:sonora/domain/repositories/library_repository.dart';
import 'package:sonora/domain/usecases/player/start_radio_use_case.dart';
import 'package:sonora/presentation/features/player/headless_session_coordinator.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';

class _FakeLibraryRepo extends Fake implements LibraryRepository {
  final List<String> recordedIds = [];

  @override
  Future<void> recordPlay(
    String videoId,
    String title,
    String artist, {
    String? thumbnailUrl,
    int? duration,
    bool isVideo = false,
    bool isExplicit = false,
    String contentType = 'song',
    String? podcastBrowseId,
  }) async {
    recordedIds.add(videoId);
  }
}

class _FakeStartRadioUseCase extends Fake implements StartRadioUseCase {
  int executeCalls = 0;

  @override
  Future<RadioResult> execute(
    String seedVideoId, {
    String? playlistId,
    bool radio = true,
    bool shuffle = false,
    bool resolveFirstUrl = true,
  }) async {
    executeCalls++;
    return RadioResult(
      const QueueTrack(
        videoId: 'up1',
        title: 'Up Next 1',
        artist: 'Radio',
        needsUrl: true,
      ).toFreshMediaItem(),
      [
        UpNextsDetails(
          type: 'SONG',
          videoId: 'up2',
          title: 'Up Next 2',
          artists: [ArtistBasic(name: 'Radio', artistId: 'UC1')],
          duration: 180,
          thumbnails: const [],
        ),
      ],
    );
  }

  @override
  List<MediaItem> toPendingItems(List<UpNextsDetails> remaining) {
    return remaining
        .map(
          (r) => QueueTrack(
            videoId: r.videoId,
            title: r.title,
            artist: r.artists.firstOrNull?.name ?? 'Radio',
            needsUrl: true,
          ).toFreshMediaItem(),
        )
        .toList(growable: false);
  }
}

void main() {
  late _FakeLibraryRepo libraryRepo;
  late _FakeStartRadioUseCase startRadio;
  late SharedPreferences prefs;
  late List<MediaItem> queue;
  late int currentIndex;
  late int? upNextStartIndex;
  late bool restoring;
  late bool offline;
  late AudioServiceRepeatMode repeatMode;
  late int? skippedTo;
  late int playCalls;
  late HeadlessSessionCoordinator coordinator;

  MediaItem trackItem(String id, {String contentType = 'song'}) {
    return QueueTrack(
      videoId: id,
      title: 'Title $id',
      artist: 'Artist $id',
      contentType: contentType,
      needsUrl: false,
      url: 'https://example.com/$id.m4a',
    ).toFreshMediaItem();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      kTrackHistoryKey: true,
      kAutoPlayUpNextKey: true,
    });
    prefs = await SharedPreferences.getInstance();
    libraryRepo = _FakeLibraryRepo();
    startRadio = _FakeStartRadioUseCase();
    queue = [trackItem('t1')];
    currentIndex = 0;
    upNextStartIndex = null;
    restoring = false;
    offline = false;
    repeatMode = AudioServiceRepeatMode.none;
    skippedTo = null;
    playCalls = 0;

    coordinator = HeadlessSessionCoordinator(
      libraryRepo: libraryRepo,
      startRadioUseCase: startRadio,
      prefs: prefs,
      isRestoring: () => restoring,
      isOffline: () => offline,
      getQueue: () => queue,
      getCurrentIndex: () => currentIndex,
      getUpNextStartIndex: () => upNextStartIndex,
      getRepeatMode: () => repeatMode,
      appendUpNext: (items) async {
        upNextStartIndex ??= queue.length;
        queue.addAll(items);
      },
      skipToQueueItem: (index) async {
        skippedTo = index;
        currentIndex = index;
      },
      play: () async {
        playCalls++;
      },
    );
  });

  group('HeadlessSessionCoordinator history tracking', () {
    test(
      'records unique plays and suppresses duplicates unless reset',
      () async {
        final t1 = trackItem('t1');
        await coordinator.onTrackChanged(t1);
        await coordinator.onTrackChanged(t1);
        expect(libraryRepo.recordedIds, ['t1']);

        coordinator.resetSession();
        await coordinator.onTrackChanged(t1);
        expect(libraryRepo.recordedIds, ['t1', 't1']);
      },
    );

    test(
      'skips recording while restoring or when tracking is disabled',
      () async {
        restoring = true;
        await coordinator.onTrackChanged(trackItem('t1'));
        expect(libraryRepo.recordedIds, isEmpty);

        restoring = false;
        await prefs.setBool(kTrackHistoryKey, false);
        await coordinator.onTrackChanged(trackItem('t2'));
        expect(libraryRepo.recordedIds, isEmpty);
      },
    );
  });

  group('HeadlessSessionCoordinator Up Next autoplay', () {
    test(
      'maybePrefetchUpNext skips when offline, repeat enabled, or episode',
      () async {
        offline = true;
        await coordinator.maybePrefetchUpNext(queue.first);
        expect(startRadio.executeCalls, 0);

        offline = false;
        repeatMode = AudioServiceRepeatMode.one;
        await coordinator.maybePrefetchUpNext(queue.first);
        expect(startRadio.executeCalls, 0);

        repeatMode = AudioServiceRepeatMode.none;
        await coordinator.maybePrefetchUpNext(
          trackItem('ep1', contentType: 'episode'),
        );
        expect(startRadio.executeCalls, 0);
      },
    );

    test('fetchUpNextAndAdvance fetches radio, appends upNext, skips, and starts playback', () async {
      await coordinator.fetchUpNextAndAdvance(queue.first);

      expect(startRadio.executeCalls, 1);
      expect(queue.map((e) => e.id).toList(), ['t1', 'up1', 'up2']);
      expect(skippedTo, 1);
      expect(playCalls, 1);
    });
  });
}

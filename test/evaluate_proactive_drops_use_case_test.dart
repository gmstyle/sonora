import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/ask_chat_models.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/domain/repositories/ask_pulse_state_store.dart';
import 'package:sonora/domain/repositories/ask_storage_repository.dart';
import 'package:sonora/domain/repositories/library_repository.dart';
import 'package:sonora/domain/repositories/llm_chat_repository.dart';
import 'package:sonora/domain/repositories/music_repository.dart';
import 'package:sonora/domain/usecases/ai/evaluate_proactive_drops_use_case.dart';

class _FakeLibraryRepo extends Fake implements LibraryRepository {
  List<HistoryModel> history = [];
  List<LikedSongModel> forgotten = [];
  List<LikedSongModel> liked = [];
  List<FollowedArtistModel> followedArtists = [];
  List<LikedAlbumModel> likedAlbums = [];
  List<LikedPodcastModel> likedPodcasts = [];

  @override
  Future<List<HistoryModel>> getRecentHistory({int limit = 50}) async =>
      history;

  @override
  Future<List<LikedSongModel>> getForgottenFavorites({
    int daysLimit = 30,
  }) async => forgotten;

  @override
  Future<List<LikedSongModel>> getAllLikedSongs() async => liked;

  @override
  Future<List<FollowedArtistModel>> getAllFollowedArtists() async =>
      followedArtists;

  @override
  Future<List<LikedAlbumModel>> getAllLikedAlbums() async => likedAlbums;

  @override
  Future<List<LikedPodcastModel>> getAllLikedPodcasts() async => likedPodcasts;
}

class _FakeAskStorageRepo extends Fake implements AskStorageRepository {
  final List<AskProactiveDrop> activeDrops = [];
  final List<AskProactiveDrop> allDrops = [];

  @override
  Future<List<AskProactiveDrop>> getActiveDrops() async =>
      List.unmodifiable(activeDrops);

  @override
  Future<List<AskProactiveDrop>> getRecentDrops({int limit = 100}) async {
    final source = allDrops.isNotEmpty ? allDrops : activeDrops;
    return List.unmodifiable(source.take(limit));
  }

  @override
  Future<void> upsertDrop(AskProactiveDrop drop) async {
    activeDrops.add(drop);
    allDrops.insert(0, drop);
  }
}

class _FakePulseStateStore implements AskPulseStateStore {
  Map<String, List<String>> releases = {};
  Map<String, List<String>> episodes = {};
  int artistCursor = 0;
  int podcastCursor = 0;

  @override
  Future<int> getArtistCursor() async => artistCursor;

  @override
  Future<int> getPodcastCursor() async => podcastCursor;

  @override
  Future<Map<String, List<String>>> getSeenEpisodesByPodcast() async =>
      Map.from(episodes);

  @override
  Future<Map<String, List<String>>> getSeenReleasesByArtist() async =>
      Map.from(releases);

  @override
  Future<void> saveSeenEpisodesByPodcast(Map<String, List<String>> seen) async {
    episodes = Map.from(seen);
  }

  @override
  Future<void> saveSeenReleasesByArtist(Map<String, List<String>> seen) async {
    releases = Map.from(seen);
  }

  @override
  Future<void> setArtistCursor(int cursor) async {
    artistCursor = cursor;
  }

  @override
  Future<void> setPodcastCursor(int cursor) async {
    podcastCursor = cursor;
  }
}

class _FakeMusicRepo extends Fake implements MusicRepository {
  Map<String, ArtistFull> artists = {};
  Map<String, PodcastFull> podcasts = {};

  @override
  Future<ArtistFull> getArtist(String artistId) async => artists[artistId]!;

  @override
  Future<PodcastFull> getPodcast(String playlistId, {int limit = 100}) async =>
      podcasts[playlistId]!;
}

class _FakeChatRepo implements LlmChatRepository {
  _FakeChatRepo({
    this.ready = true,
    this.replyContent = '{"title":"Heavy M83 Rotation","body":"You played M83 a lot lately.","starterPrompt":"Build a mix inspired by M83"}',
    this.shouldThrow = false,
  });

  bool ready;
  String replyContent;
  bool shouldThrow;
  int calls = 0;
  AskActionKind? lastAction;
  bool? lastJsonMode;
  String? lastUserMessage;

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<AskQuotaInfo?> fetchQuota() async => AskQuotaInfo.unlimited();

  @override
  Future<AskPulseRemoteConfig?> fetchPulseConfig({
    required String locale,
  }) async => AskPulseRemoteConfig.defaults();

  @override
  Future<LlmChatResponse> completeChat({
    required AskActionKind action,
    required List<LlmChatMessage> messages,
    String? systemInstruction,
    String locale = 'en',
    List<LlmToolDefinition> tools = const [],
    String? toolChoice,
    bool enableWebSearch = false,
    bool jsonMode = false,
    int maxOutputTokens = 900,
    String? turnId,
  }) async {
    calls++;
    lastAction = action;
    lastJsonMode = jsonMode;
    lastUserMessage = messages.isNotEmpty ? messages.last.content : null;
    if (shouldThrow) {
      throw StateError('boom');
    }
    return LlmChatResponse(content: replyContent);
  }
}

void main() {
  // Saturday 2026-11-21 18:00 (neutral day for non-weekly-recap tests).
  final now = DateTime(2026, 11, 21, 18, 0);

  HistoryModel hist(
    String id,
    String artist,
    int plays, {
    Duration ago = const Duration(hours: 2),
  }) => HistoryModel(
    id: id.hashCode,
    videoId: id,
    title: 'Track $id',
    artist: artist,
    playedAt: now.subtract(ago),
    playCount: plays,
  );

  LikedSongModel song(String id, String artist) => LikedSongModel(
    videoId: id,
    title: 'Song $id',
    artist: artist,
    addedAt: now.subtract(const Duration(days: 45)),
  );

  test(
    'emits heavy_rotation drop and persists it when playCount >= 4',
    () async {
      final lib = _FakeLibraryRepo()
        ..history = [hist('v1', 'M83', 5), hist('v2', 'Daft Punk', 2)];
      final storage = _FakeAskStorageRepo();
      final chat = _FakeChatRepo();
      final useCase = EvaluateProactiveDropsUseCase(
        lib,
        storage,
        chat,
        now: () => now,
      );

      final drop = await useCase.execute(locale: 'en');

      expect(drop, isNotNull);
      expect(drop!.kind, 'heavy_rotation');
      expect(drop.seedId, 'heavy:m83');
      expect(drop.title, 'Heavy M83 Rotation');
      expect(storage.activeDrops, hasLength(1));
      expect(chat.calls, 1);
      expect(chat.lastAction, AskActionKind.pulseDrop);
      expect(chat.lastJsonMode, isTrue);
    },
  );

  test(
    'respects 48h cooldown across dismissed drops without calling LLM',
    () async {
      final lib = _FakeLibraryRepo()..history = [hist('v1', 'M83', 6)];
      final storage = _FakeAskStorageRepo()
        ..allDrops.add(
          AskProactiveDrop(
            id: 'drop_dismissed',
            kind: 'heavy_rotation',
            title: 'Recent dismissed',
            body: 'Body',
            starterPrompt: 'Prompt',
            seedId: 'heavy:other',
            createdAt: now.subtract(const Duration(hours: 12)),
            dismissedAt: now.subtract(const Duration(hours: 10)),
          ),
        );
      final chat = _FakeChatRepo();
      final useCase = EvaluateProactiveDropsUseCase(
        lib,
        storage,
        chat,
        now: () => now,
      );

      final drop = await useCase.execute(locale: 'en');
      expect(drop, isNull);
      expect(chat.calls, 0);
    },
  );

  test('skips used heavy seed and falls through to forgotten_favorites and taste_discovery', () async {
    final lib = _FakeLibraryRepo()
      ..history = [hist('v1', 'M83', 6)]
      ..forgotten = [
        song('f1', 'Phoenix'),
        song('f2', 'Justice'),
        song('f3', 'Air'),
      ]
      ..liked = [song('l1', 'Bicep'), song('l2', 'Kavinsky')];

    final storage = _FakeAskStorageRepo()
      ..allDrops.add(
        AskProactiveDrop(
          id: 'drop_prev',
          kind: 'heavy_rotation',
          title: 'Old M83',
          body: 'Body',
          starterPrompt: 'Prompt',
          seedId: 'heavy:m83',
          createdAt: now.subtract(const Duration(hours: 72)),
          dismissedAt: now.subtract(const Duration(hours: 60)),
        ),
      );
    final chat = _FakeChatRepo(
      replyContent: '```json\n{"title":"Rediscover","body":"Old favorites waiting.","starterPrompt":"Play my forgotten gems"}\n```',
    );
    final useCase = EvaluateProactiveDropsUseCase(
      lib,
      storage,
      chat,
      now: () => now,
    );

    final drop1 = await useCase.execute(locale: 'it');
    expect(drop1, isNotNull);
    expect(drop1!.kind, 'forgotten_favorites');
    expect(drop1.seedId, 'forgotten_favorites');
    expect(drop1.title, 'Rediscover');

    // Age the drop beyond 48h and verify fallback to taste_discovery
    storage.allDrops
      ..clear()
      ..addAll([
        AskProactiveDrop(
          id: 'drop_prev',
          kind: 'heavy_rotation',
          title: 'Old M83',
          body: 'Body',
          starterPrompt: 'Prompt',
          seedId: 'heavy:m83',
          createdAt: now.subtract(const Duration(hours: 96)),
        ),
        AskProactiveDrop(
          id: drop1.id,
          kind: drop1.kind,
          title: drop1.title,
          body: drop1.body,
          starterPrompt: drop1.starterPrompt,
          seedId: drop1.seedId,
          createdAt: now.subtract(const Duration(hours: 72)),
        ),
      ]);
    lib.liked = [
      song('l1', 'Bicep'),
      song('l2', 'Kavinsky'),
      song('l3', 'Carpenters'),
      song('l4', 'Roosevelt'),
    ];

    final drop2 = await useCase.execute(locale: 'it');
    expect(drop2, isNotNull);
    expect(drop2!.kind, 'taste_discovery');
    expect(drop2.seedId, 'taste_discovery');
  });

  test('new_release baseline seeds silently on first check, then notifies on new album', () async {
    final lib = _FakeLibraryRepo()
      ..followedArtists = [
        FollowedArtistModel(
          artistId: 'UC_M83',
          name: 'M83',
          addedAt: now.subtract(const Duration(days: 10)),
        ),
      ];
    final storage = _FakeAskStorageRepo();
    final stateStore = _FakePulseStateStore();
    final musicRepo = _FakeMusicRepo()
      ..artists['UC_M83'] = ArtistFull(
        artistId: 'UC_M83',
        name: 'M83',
        type: 'ARTIST',
        thumbnails: const [],
        topSongs: const [],
        topAlbums: [
          AlbumDetailed(
            type: 'ALBUM',
            albumId: 'MPRE_OLD',
            playlistId: 'OLAK_OLD',
            name: 'Fantasy',
            year: 2023,
            thumbnails: const [],
          ),
        ],
        topSingles: const [],
        featuredOn: const [],
        similarArtists: const [],
        topVideos: const [],
      );
    final chat = _FakeChatRepo(
      replyContent: '{"title":"Nuovo album M83","body":"È uscito Echoes!","starterPrompt":"Fammi ascoltare Echoes"}',
    );
    final useCase = EvaluateProactiveDropsUseCase(
      lib,
      storage,
      chat,
      musicRepository: musicRepo,
      stateStore: stateStore,
      now: () => now,
    );

    // First run: baseline seeding only -> no drop, no LLM call.
    final first = await useCase.execute(locale: 'it');
    expect(first, isNull);
    expect(chat.calls, 0);
    expect(stateStore.releases['UC_M83'], ['MPRE_OLD']);

    // New release appears on second run -> emits new_release.
    musicRepo.artists['UC_M83'] = ArtistFull(
      artistId: 'UC_M83',
      name: 'M83',
      type: 'ARTIST',
      thumbnails: const [],
      topSongs: const [],
      topAlbums: [
        AlbumDetailed(
          type: 'ALBUM',
          albumId: 'MPRE_NEW_2026',
          playlistId: 'OLAK_NEW',
          name: 'Echoes',
          year: 2026,
          thumbnails: const [],
        ),
        AlbumDetailed(
          type: 'ALBUM',
          albumId: 'MPRE_OLD',
          playlistId: 'OLAK_OLD',
          name: 'Fantasy',
          year: 2023,
          thumbnails: const [],
        ),
      ],
      topSingles: const [],
      featuredOn: const [],
      similarArtists: const [],
      topVideos: const [],
    );

    final second = await useCase.execute(locale: 'it');
    expect(second, isNotNull);
    expect(second!.kind, 'new_release');
    expect(second.seedId, 'release:mpre_new_2026');
    expect(chat.calls, 1);
    expect(stateStore.releases['UC_M83'], contains('MPRE_NEW_2026'));
  });

  test(
    'new_podcast_episode baseline seeds then emits on new episode',
    () async {
      final lib = _FakeLibraryRepo()
        ..likedPodcasts = [
          LikedPodcastModel(
            browseId: 'MPSP_1',
            name: 'Tech & Sound',
            addedAt: now.subtract(const Duration(days: 5)),
          ),
        ];
      final storage = _FakeAskStorageRepo();
      final stateStore = _FakePulseStateStore();
      final musicRepo = _FakeMusicRepo()
        ..podcasts['MPSP_1'] = PodcastFull(
          browseId: 'MPSP_1',
          name: 'Tech & Sound',
          thumbnails: const [],
          episodes: [
            PodcastEpisode(
              videoId: 'ep_1',
              browseId: 'MPED_1',
              name: 'Episode 1',
              thumbnails: const [],
            ),
          ],
        );
      final chat = _FakeChatRepo(
        replyContent: '{"title":"New episode","body":"Episode 2 is out!","starterPrompt":"Tell me about Tech & Sound"}',
      );
      final useCase = EvaluateProactiveDropsUseCase(
        lib,
        storage,
        chat,
        musicRepository: musicRepo,
        stateStore: stateStore,
        now: () => now,
      );

      expect(await useCase.execute(locale: 'en'), isNull);
      expect(stateStore.episodes['MPSP_1'], ['ep_1']);

      musicRepo.podcasts['MPSP_1'] = PodcastFull(
        browseId: 'MPSP_1',
        name: 'Tech & Sound',
        thumbnails: const [],
        episodes: [
          PodcastEpisode(
            videoId: 'ep_2',
            browseId: 'MPED_2',
            name: 'Episode 2',
            thumbnails: const [],
          ),
          PodcastEpisode(
            videoId: 'ep_1',
            browseId: 'MPED_1',
            name: 'Episode 1',
            thumbnails: const [],
          ),
        ],
      );

      final drop = await useCase.execute(locale: 'en');
      expect(drop, isNotNull);
      expect(drop!.kind, 'new_podcast_episode');
      expect(drop.seedId, 'episode:ep_2');
    },
  );

  test('emits comeback_mix after >= 5 days without plays', () async {
    final lib = _FakeLibraryRepo()
      ..history = [hist('v1', 'Justice', 5, ago: const Duration(days: 6))];
    final storage = _FakeAskStorageRepo();
    final chat = _FakeChatRepo(
      replyContent: '{"title":"Bentornato!","body":"È passata una settimana da Justice.","starterPrompt":"Fammi un mix per ripartire"}',
    );
    final useCase = EvaluateProactiveDropsUseCase(
      lib,
      storage,
      chat,
      now: () => now,
    );

    final drop = await useCase.execute(locale: 'it');
    expect(drop, isNotNull);
    expect(drop!.kind, 'comeback_mix');
    expect(drop.seedId, startsWith('comeback:'));
  });

  test(
    'emits weekly_recap on Friday evening with >= 5 plays and skips on Tuesday',
    () async {
      final fridayEvening = DateTime(2026, 11, 20, 18, 0);
      final tuesday = DateTime(2026, 11, 17, 18, 0);
      final lib = _FakeLibraryRepo()
        ..history = [
          HistoryModel(
            id: 1,
            videoId: 'v1',
            title: 'Genesis',
            artist: 'Justice',
            playedAt: fridayEvening.subtract(const Duration(days: 1)),
            playCount: 6,
          ),
        ];
      final storage = _FakeAskStorageRepo();
      final chat = _FakeChatRepo(
        replyContent: '{"title":"Recap della settimana","body":"Justice in cima ai tuoi ascolti.","starterPrompt":"Espandi il mood di questa settimana"}',
      );

      final tuesdayDrop =
          await EvaluateProactiveDropsUseCase(
            lib,
            storage,
            chat,
            now: () => tuesday,
          ).execute(
            locale: 'it',
            remoteConfig: const AskPulseRemoteConfig(
              enabledTriggers: {'weekly_recap'},
            ),
          );
      expect(tuesdayDrop, isNull);

      final fridayDrop =
          await EvaluateProactiveDropsUseCase(
            lib,
            storage,
            chat,
            now: () => fridayEvening,
          ).execute(
            locale: 'it',
            remoteConfig: const AskPulseRemoteConfig(
              enabledTriggers: {'weekly_recap'},
            ),
          );
      expect(fridayDrop, isNotNull);
      expect(fridayDrop!.kind, 'weekly_recap');
      expect(fridayDrop.seedId, startsWith('weekly_recap:'));
    },
  );

  test(
    'emits editorial_pulse when Cloudflare editorial spark is present',
    () async {
      final lib = _FakeLibraryRepo()
        ..history = [hist('v1', 'Bicep', 2)]
        ..liked = [song('s1', 'Four Tet'), song('s2', 'Floating Points')];
      final storage = _FakeAskStorageRepo();
      final chat = _FakeChatRepo(
        replyContent: '{"title":"New Music Friday","body":"Pronto per scoprire suoni freschi con Bicep?","starterPrompt":"Crea un mix elettronico per venerdì"}',
      );
      const remoteConfig = AskPulseRemoteConfig(
        editorialPulse: AskEditorialPulse(
          id: 'editorial:2026-W47:2026-11-21:it',
          theme: 'Electronic Friday',
          hook: 'Weekend warmup',
          moodKeywords: ['synth', 'deep'],
          promptAngle: 'Fresh night drive',
        ),
      );

      final drop = await EvaluateProactiveDropsUseCase(
        lib,
        storage,
        chat,
        now: () => now,
      ).execute(locale: 'it', remoteConfig: remoteConfig);

      expect(drop, isNotNull);
      expect(drop!.kind, 'editorial_pulse');
      expect(drop.seedId, 'editorial:editorial:2026-w47:2026-11-21:it');
    },
  );

  test(
    'honors remote kill switch and weekly quota exhaustion without calling LLM',
    () async {
      final lib = _FakeLibraryRepo()..history = [hist('v1', 'M83', 6)];
      final storage = _FakeAskStorageRepo();
      final chat = _FakeChatRepo();
      final useCase = EvaluateProactiveDropsUseCase(
        lib,
        storage,
        chat,
        now: () => now,
      );

      expect(
        await useCase.execute(
          locale: 'en',
          remoteConfig: const AskPulseRemoteConfig(enabled: false),
        ),
        isNull,
      );
      expect(
        await useCase.execute(
          locale: 'en',
          remoteConfig: const AskPulseRemoteConfig(weeklyRemaining: 0),
        ),
        isNull,
      );
      expect(chat.calls, 0);
    },
  );

  test('returns null cleanly when offline/not ready, malformed JSON, or chat throws', () async {
    final lib = _FakeLibraryRepo()..history = [hist('v1', 'M83', 6)];
    final storage = _FakeAskStorageRepo();

    final notReady = _FakeChatRepo(ready: false);
    expect(
      await EvaluateProactiveDropsUseCase(
        lib,
        storage,
        notReady,
        now: () => now,
      ).execute(locale: 'en'),
      isNull,
    );
    expect(notReady.calls, 0);

    final malformed = _FakeChatRepo(replyContent: 'not json at all');
    expect(
      await EvaluateProactiveDropsUseCase(
        lib,
        storage,
        malformed,
        now: () => now,
      ).execute(locale: 'en'),
      isNull,
    );

    final throwsRepo = _FakeChatRepo(shouldThrow: true);
    expect(
      await EvaluateProactiveDropsUseCase(
        lib,
        storage,
        throwsRepo,
        now: () => now,
      ).execute(locale: 'en'),
      isNull,
    );
    expect(storage.activeDrops, isEmpty);
  });
}

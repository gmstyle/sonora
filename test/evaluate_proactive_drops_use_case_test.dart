import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/ask_chat_models.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/domain/repositories/ask_storage_repository.dart';
import 'package:sonora/domain/repositories/library_repository.dart';
import 'package:sonora/domain/repositories/llm_chat_repository.dart';
import 'package:sonora/domain/usecases/ai/evaluate_proactive_drops_use_case.dart';

class _FakeLibraryRepo extends Fake implements LibraryRepository {
  List<HistoryModel> history = [];
  List<LikedSongModel> forgotten = [];
  List<LikedSongModel> liked = [];

  @override
  Future<List<HistoryModel>> getRecentHistory({int limit = 50}) async =>
      history;

  @override
  Future<List<LikedSongModel>> getForgottenFavorites({
    int daysLimit = 30,
  }) async => forgotten;

  @override
  Future<List<LikedSongModel>> getAllLikedSongs() async => liked;
}

class _FakeAskStorageRepo extends Fake implements AskStorageRepository {
  final List<AskProactiveDrop> activeDrops = [];

  @override
  Future<List<AskProactiveDrop>> getActiveDrops() async =>
      List.unmodifiable(activeDrops);

  @override
  Future<void> upsertDrop(AskProactiveDrop drop) async {
    activeDrops.add(drop);
  }
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

  @override
  Future<bool> isReady() async => ready;

  @override
  Future<AskQuotaInfo?> fetchQuota() async => AskQuotaInfo.unlimited();

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
    if (shouldThrow) {
      throw StateError('boom');
    }
    return LlmChatResponse(content: replyContent);
  }
}

void main() {
  final now = DateTime(2026, 11, 21, 18, 0);

  HistoryModel hist(String id, String artist, int plays) => HistoryModel(
    id: id.hashCode,
    videoId: id,
    title: 'Track $id',
    artist: artist,
    playedAt: now.subtract(const Duration(hours: 2)),
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
    'respects 48h cooldown when an active drop is recent without calling LLM',
    () async {
      final lib = _FakeLibraryRepo()..history = [hist('v1', 'M83', 6)];
      final storage = _FakeAskStorageRepo()
        ..activeDrops.add(
          AskProactiveDrop(
            id: 'drop_old',
            kind: 'heavy_rotation',
            title: 'Recent',
            body: 'Body',
            starterPrompt: 'Prompt',
            seedId: 'heavy:other',
            createdAt: now.subtract(const Duration(hours: 12)),
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
      ..activeDrops.add(
        AskProactiveDrop(
          id: 'drop_prev',
          kind: 'heavy_rotation',
          title: 'Old M83',
          body: 'Body',
          starterPrompt: 'Prompt',
          seedId: 'heavy:m83',
          createdAt: now.subtract(const Duration(hours: 72)),
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
    storage.activeDrops
      ..removeLast()
      ..add(
        AskProactiveDrop(
          id: drop1.id,
          kind: drop1.kind,
          title: drop1.title,
          body: drop1.body,
          starterPrompt: drop1.starterPrompt,
          seedId: drop1.seedId,
          createdAt: now.subtract(const Duration(hours: 72)),
        ),
      );
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

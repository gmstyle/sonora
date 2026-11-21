import 'dart:convert';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/ask_chat_models.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/domain/repositories/library_repository.dart';
import 'package:sonora/domain/repositories/llm_chat_repository.dart';
import 'package:sonora/domain/repositories/music_repository.dart';
import 'package:sonora/domain/usecases/ai/ask_agent_use_case.dart';
import 'package:sonora/domain/usecases/ai/ask_tool_executor.dart';

class _FakeChatRepo implements LlmChatRepository {
  _FakeChatRepo(this.onTurn);

  final LlmChatResponse Function(
    int callIndex,
    List<LlmChatMessage> messages,
    String? turnId,
  )
  onTurn;

  final List<String?> seenTurnIds = [];
  int _calls = 0;

  @override
  Future<bool> isReady() async => true;

  @override
  Future<AskQuotaInfo?> fetchQuota() async => AskQuotaInfo.unlimited();

  @override
  Future<LlmChatResponse> completeChat({
    required AskActionKind action,
    required List<LlmChatMessage> messages,
    String? systemInstruction,
    String locale = 'en',
    List<LlmToolDefinition> tools = const [],
    bool enableWebSearch = false,
    bool jsonMode = false,
    int maxOutputTokens = 900,
    String? turnId,
  }) async {
    seenTurnIds.add(turnId);
    final idx = _calls++;
    return onTurn(idx, messages, turnId);
  }
}

class _FakeLibraryRepo extends Fake implements LibraryRepository {
  int mutationCalls = 0;

  final List<HistoryModel> history = [
    HistoryModel(
      id: 1,
      videoId: 'real_hist_1',
      title: 'Midnight City',
      artist: 'M83',
      playedAt: DateTime(2026, 11, 20),
      playCount: 12,
      duration: 244,
    ),
  ];

  final List<LikedSongModel> liked = [
    LikedSongModel(
      videoId: 'real_liked_1',
      title: 'Instant Crush',
      artist: 'Daft Punk',
      addedAt: DateTime(2026, 11, 1),
      duration: 337,
    ),
  ];

  @override
  Future<List<HistoryModel>> getMostPlayedSongs({int limit = 50}) async =>
      history;

  @override
  Future<List<HistoryModel>> getRecentHistory({int limit = 50}) async =>
      history;

  @override
  Future<List<LikedSongModel>> getAllLikedSongs() async => liked;

  @override
  Future<List<FollowedArtistModel>> getAllFollowedArtists() async => [
    FollowedArtistModel(
      artistId: 'UC_M83',
      name: 'M83',
      addedAt: DateTime(2026, 1, 1),
    ),
  ];

  @override
  Future<List<LocalPlaylistModel>> getAllPlaylists() async => const [];

  @override
  Future<List<PlaylistEntryModel>> getPlaylistEntries(int playlistId) async =>
      const [];

  @override
  Future<int> createPlaylist(
    String name, {
    String? description,
    String? sourceKind,
    String? remoteId,
    String? remoteName,
    String linkStatus = 'local',
    DateTime? lastSyncedAt,
  }) async {
    mutationCalls++;
    return 1;
  }

  @override
  Future<void> addEntry(
    int playlistId,
    String videoId,
    int position, {
    String? title,
    String? artist,
    String? artistsJson,
    String? thumbnailUrl,
    int? duration,
    bool isVideo = false,
    bool isExplicit = false,
  }) async {
    mutationCalls++;
  }
}

class _FakeMusicRepo extends Fake implements MusicRepository {
  @override
  Future<List<SongDetailed>> searchSongs(String query, {int limit = 20}) async {
    return [
      SongDetailed(
        type: 'SONG',
        videoId: 'real_ytm_1',
        name: 'Resonance',
        artists: [ArtistBasic(name: 'HOME', artistId: 'UC_HOME')],
        duration: 212,
        thumbnails: const [],
      ),
    ];
  }
}

void main() {
  group('AskToolExecutor & AskAgentUseCase', () {
    test('shares one turnId across rounds, validates grounded IDs, and never mutates Drift', () async {
      final library = _FakeLibraryRepo();
      final music = _FakeMusicRepo();
      final executor = AskToolExecutor(
        libraryRepository: library,
        musicRepository: music,
        readNowPlaying: () => const AskNowPlayingSnapshot(
          videoId: 'real_np_1',
          title: 'Veridis Quo',
          artist: 'Daft Punk',
        ),
      );

      final repo = _FakeChatRepo((round, messages, turnId) {
        if (round == 0) {
          return const LlmChatResponse(
            toolCalls: [
              AskToolCall(id: 'c1', name: 'get_taste_profile', arguments: {}),
              AskToolCall(
                id: 'c2',
                name: 'search_catalog',
                arguments: {'query': 'synthwave', 'type': 'songs'},
              ),
            ],
          );
        }
        if (round == 1) {
          return const LlmChatResponse(
            toolCalls: [
              AskToolCall(
                id: 'c3',
                name: 'propose_mix',
                arguments: {
                  'title': 'Night Drive',
                  'videoIds': ['real_hist_1', 'HALLUCINATED_ID', 'real_ytm_1'],
                },
              ),
              AskToolCall(
                id: 'c4',
                name: 'propose_playlist_write',
                arguments: {
                  'operation': 'create',
                  'playlistName': 'Night Drive Saved',
                  'videoIds': ['real_liked_1', 'FAKE_ID'],
                },
              ),
            ],
          );
        }
        return const LlmChatResponse(
          content: 'Ho preparato il mix e la proposta da confermare.',
        );
      });

      final uc = AskAgentUseCase(repo);
      final result = await uc.execute(
        userMessage: 'Crea un mix notturno per guidare',
        executor: executor,
        locale: 'it',
      );

      expect(repo.seenTurnIds, hasLength(3));
      expect(repo.seenTurnIds.toSet(), hasLength(1));
      expect(result.assistantText, contains('Ho preparato'));
      expect(result.toolNamesUsed, [
        'get_taste_profile',
        'search_catalog',
        'propose_mix',
        'propose_playlist_write',
      ]);

      // Safe Write: zero Drift mutations performed during tool execution.
      expect(library.mutationCalls, 0);

      // Grounding guard stripped hallucinated IDs from both attachments.
      expect(result.attachments, hasLength(2));
      final mix = result.attachments[0] as AskMixAttachment;
      expect(mix.tracks.map((t) => t.videoId), ['real_hist_1', 'real_ytm_1']);

      final writeProp = result.attachments[1] as AskPlaylistWriteProposal;
      expect(writeProp.isPending, isTrue);
      expect(writeProp.tracks.map((t) => t.videoId), ['real_liked_1']);
    });

    test('useTasteContext=false disables get_taste_profile and get_listening_history', () async {
      final executor = AskToolExecutor(
        libraryRepository: _FakeLibraryRepo(),
        musicRepository: _FakeMusicRepo(),
        useTasteContext: false,
      );

      final res1 = await executor.execute(
        const AskToolCall(id: '1', name: 'get_taste_profile', arguments: {}),
      );
      final res2 = await executor.execute(
        const AskToolCall(
          id: '2',
          name: 'get_listening_history',
          arguments: {},
        ),
      );

      expect(jsonDecode(res1.contentJson), {'disabledByUser': true});
      expect(jsonDecode(res2.contentJson), {'disabledByUser': true});
    });
  });
}

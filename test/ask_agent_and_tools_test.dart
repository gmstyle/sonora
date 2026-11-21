import 'dart:convert';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/constants/ai_constants.dart';
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
  final List<int> seenMaxOutputTokens = [];
  final List<String?> seenToolChoices = [];
  final List<int> seenToolCounts = [];
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
    String? toolChoice,
    bool enableWebSearch = false,
    bool jsonMode = false,
    int maxOutputTokens = 900,
    String? turnId,
  }) async {
    seenTurnIds.add(turnId);
    seenMaxOutputTokens.add(maxOutputTokens);
    seenToolChoices.add(toolChoice);
    seenToolCounts.add(tools.length);
    final idx = _calls++;
    return onTurn(idx, messages, turnId);
  }
}

class _FakeLibraryRepo extends Fake implements LibraryRepository {
  int mutationCalls = 0;
  List<LocalPlaylistModel> playlists = const [];
  Map<int, List<PlaylistEntryModel>> entriesByPlaylist = const {};

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
  Future<List<LocalPlaylistModel>> getAllPlaylists() async => playlists;

  @override
  Future<List<PlaylistEntryModel>> getPlaylistEntries(int playlistId) async =>
      entriesByPlaylist[playlistId] ?? const [];

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

    test('handles >24 wireMessages across multi-round parallel tool calls, sanitizes history, and sets maxOutputTokens=2048', () async {
      final executor = AskToolExecutor(
        libraryRepository: _FakeLibraryRepo(),
        musicRepository: _FakeMusicRepo(),
      );

      final history = [
        AskChatMessage(
          id: 'h1',
          conversationId: 'c1',
          role: 'user',
          content: 'Crea una playlist R&B',
          createdAt: DateTime(2026, 11, 21),
        ),
        AskChatMessage(
          id: 'h2',
          conversationId: 'c1',
          role: 'assistant',
          content: '',
          attachments: const [
            AskPlaylistWriteProposal(
              operation: 'create',
              playlistName: 'R&B Notturno',
              tracks: [
                AskTrackRef(
                  videoId: 'real_hist_1',
                  title: 'Midnight City',
                  artist: 'M83',
                ),
              ],
              status: 'saved',
            ),
          ],
          createdAt: DateTime(2026, 11, 21),
        ),
        AskChatMessage(
          id: 'h3',
          conversationId: 'c1',
          role: 'assistant',
          content: '',
          createdAt: DateTime(2026, 11, 21),
        ),
        AskChatMessage(
          id: 'h4',
          conversationId: 'c1',
          role: 'assistant',
          content: 'failed error',
          isError: true,
          createdAt: DateTime(2026, 11, 21),
        ),
      ];

      List<LlmChatMessage> capturedFinalMessages = const [];
      final repo = _FakeChatRepo((round, messages, turnId) {
        capturedFinalMessages = List.of(messages);
        if (round < 2) {
          return LlmChatResponse(
            toolCalls: [
              for (var i = 0; i < 12; i++)
                AskToolCall(
                  id: 'r${round}_$i',
                  name: 'search_catalog',
                  arguments: {'query': 'rnb $round $i', 'type': 'songs'},
                ),
            ],
          );
        }
        return const LlmChatResponse(content: 'Portata a 50 brani!');
      });

      final res = await AskAgentUseCase(repo).execute(
        userMessage: 'portala a 50 brani',
        executor: executor,
        history: history,
        locale: 'it',
      );

      expect(res.assistantText, 'Portata a 50 brani!');
      expect(repo.seenTurnIds.toSet(), hasLength(1));
      expect(repo.seenMaxOutputTokens, everyElement(2048));
      // Initial 3 messages (1 user + 1 attachment summary + current user; blank + error skipped)
      // plus 2 rounds * (1 assistant + 12 tool replies) = 29 messages.
      expect(capturedFinalMessages.length, greaterThan(24));
      expect(
        capturedFinalMessages.any(
          (m) =>
              m.role == 'assistant' &&
              (m.content ?? '').contains('R&B Notturno'),
        ),
        isTrue,
      );
      expect(
        capturedFinalMessages.any((m) => m.content == 'failed error'),
        isFalse,
      );
    });

    test(
      'get_local_playlist_tracks exposes totalTracks and up to 80 entries',
      () async {
        final library = _FakeLibraryRepo()
          ..playlists = [
            LocalPlaylistModel(
              id: 7,
              name: 'R&B Notturno',
              createdAt: DateTime(2026, 11, 21),
            ),
          ]
          ..entriesByPlaylist = {
            7: [
              for (var i = 0; i < 45; i++)
                PlaylistEntryModel(
                  playlistId: 7,
                  videoId: 'v_$i',
                  position: i,
                  title: 'Song $i',
                  artist: 'Artist $i',
                ),
            ],
          };

        final executor = AskToolExecutor(
          libraryRepository: library,
          musicRepository: _FakeMusicRepo(),
        );
        final res = await executor.execute(
          const AskToolCall(
            id: 'pl1',
            name: 'get_local_playlist_tracks',
            arguments: {'playlistName': 'r&b notturno'},
          ),
        );

        final decoded = jsonDecode(res.contentJson) as Map<String, dynamic>;
        expect(decoded['totalTracks'], 45);
        expect(decoded['tracks'], hasLength(45));
      },
    );

    test('wrap-up round keeps tools attached with toolChoice=none after max tool rounds', () async {
      final executor = AskToolExecutor(
        libraryRepository: _FakeLibraryRepo(),
        musicRepository: _FakeMusicRepo(),
      );
      final repo = _FakeChatRepo((round, messages, turnId) {
        if (round < 6) {
          return LlmChatResponse(
            toolCalls: [
              AskToolCall(
                id: 'call_$round',
                name: 'search_catalog',
                arguments: {'query': 'q$round', 'type': 'songs'},
              ),
            ],
          );
        }
        return const LlmChatResponse(content: 'Riepilogo finale');
      });

      final res = await AskAgentUseCase(repo).execute(
        userMessage: 'fammi una grande playlist',
        executor: executor,
        locale: 'it',
      );

      expect(res.assistantText, 'Riepilogo finale');
      expect(repo.seenToolCounts, hasLength(7));
      expect(repo.seenToolCounts, everyElement(executor.definitions.length));
      expect(repo.seenToolChoices.sublist(0, 6), everyElement(isNull));
      expect(repo.seenToolChoices.last, 'none');
    });

    test('caps per-round tool calls at kAskMaxToolCallsPerRound with 1:1 tool response parity', () async {
      final executor = AskToolExecutor(
        libraryRepository: _FakeLibraryRepo(),
        musicRepository: _FakeMusicRepo(),
      );
      late List<LlmChatMessage> secondRoundMessages;
      final repo = _FakeChatRepo((round, messages, turnId) {
        if (round == 0) {
          return LlmChatResponse(
            toolCalls: [
              for (var i = 0; i < 28; i++)
                AskToolCall(
                  id: 'call_$i',
                  name: 'search_catalog',
                  arguments: {'query': 'song $i', 'type': 'songs'},
                ),
            ],
          );
        }
        secondRoundMessages = List.of(messages);
        return const LlmChatResponse(content: 'Fatto!');
      });

      final res = await AskAgentUseCase(repo).execute(
        userMessage: 'espandi a 50 brani',
        executor: executor,
        locale: 'it',
      );

      expect(res.assistantText, 'Fatto!');
      final assistantMsg = secondRoundMessages.firstWhere(
        (m) => m.role == 'assistant' && m.toolCalls.isNotEmpty,
      );
      final toolMsgs = secondRoundMessages
          .where((m) => m.role == 'tool')
          .toList(growable: false);
      expect(assistantMsg.toolCalls, hasLength(kAskMaxToolCallsPerRound));
      expect(toolMsgs, hasLength(kAskMaxToolCallsPerRound));
      expect(
        assistantMsg.toolCalls.map((c) => c.id),
        toolMsgs.map((m) => m.toolCallId),
      );
    });

    test('strips leaked DSML from historical assistant messages and includes attachment summary with text', () async {
      final executor = AskToolExecutor(
        libraryRepository: _FakeLibraryRepo(),
        musicRepository: _FakeMusicRepo(),
      );
      final history = [
        AskChatMessage(
          id: 'h_user',
          conversationId: 'c1',
          role: 'user',
          content: 'Crea una playlist chill',
          createdAt: DateTime(2026, 11, 21),
        ),
        AskChatMessage(
          id: 'h_assistant_dsml',
          conversationId: 'c1',
          role: 'assistant',
          content: '<｜｜DSML｜｜ calls><｜｜DSML｜｜ invoke name="search_catalog"></｜｜DSML｜｜ invoke></｜｜DSML｜｜ calls>',
          createdAt: DateTime(2026, 11, 21),
        ),
        AskChatMessage(
          id: 'h_assistant_mixed',
          conversationId: 'c1',
          role: 'assistant',
          content:
              'Ecco il tuo mix <｜｜DSML｜｜ invoke name="x"></｜｜DSML｜｜ invoke>',
          attachments: const [
            AskMixAttachment(
              title: 'R&B Notturno',
              tracks: [
                AskTrackRef(
                  videoId: 'real_hist_1',
                  title: 'Midnight City',
                  artist: 'M83',
                ),
              ],
            ),
          ],
          createdAt: DateTime(2026, 11, 21),
        ),
      ];

      late List<LlmChatMessage> sentMessages;
      final repo = _FakeChatRepo((round, messages, turnId) {
        sentMessages = List.of(messages);
        return const LlmChatResponse(content: 'Ok!');
      });

      await AskAgentUseCase(repo).execute(
        userMessage: 'portala a 50',
        executor: executor,
        history: history,
        locale: 'it',
      );

      expect(
        sentMessages.any((m) => (m.content ?? '').contains('DSML')),
        isFalse,
      );
      final assistantHistory = sentMessages.singleWhere(
        (m) => m.role == 'assistant',
      );
      expect(assistantHistory.content, contains('Ecco il tuo mix'));
      expect(
        assistantHistory.content,
        contains('[Mix "R&B Notturno": 1 tracks]'),
      );
    });
  });
}

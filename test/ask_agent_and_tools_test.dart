import 'dart:convert';
import 'dart:math';

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
  Future<LocalPlaylistModel?> getPlaylist(int id) async {
    for (final p in playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<List<LikedAlbumModel>> getAllLikedAlbums() async => const [];

  @override
  Future<List<LikedPodcastModel>> getAllLikedPodcasts() async => const [];

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
        album: AlbumBasic(albumId: 'MPRE_RES', name: 'Odyssey'),
        duration: 212,
        thumbnails: [
          ThumbnailFull(
            url: 'https://img.example/resonance.jpg',
            width: 226,
            height: 226,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<ArtistDetailed>> searchArtists(
    String query, {
    int limit = 20,
  }) async {
    return [
      ArtistDetailed(
        type: 'ARTIST',
        artistId: 'UC_MEREBA',
        name: 'Mereba',
        monthlyListeners: '1.2M',
        thumbnails: [
          ThumbnailFull(
            url: 'https://img.example/mereba.jpg',
            width: 226,
            height: 226,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<AlbumDetailed>> searchAlbums(
    String query, {
    int limit = 20,
  }) async {
    return [
      AlbumDetailed(
        type: 'ALBUM',
        albumId: 'MPRE_SNOH',
        playlistId: 'OLAK_SNOH',
        name: 'Temporary Highs in the Violet Skies',
        artists: [ArtistBasic(name: 'Snoh Aalegra', artistId: 'UC_SNOH')],
        year: 2021,
        thumbnails: [
          ThumbnailFull(
            url: 'https://img.example/album.jpg',
            width: 226,
            height: 226,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<PlaylistDetailed>> searchPlaylists(
    String query, {
    int limit = 20,
  }) async {
    return [
      PlaylistDetailed(
        type: 'PLAYLIST',
        playlistId: 'RDCLAK_SOUL',
        name: 'Neo-Soul Essentials',
        artists: [ArtistBasic(name: 'YouTube Music')],
        thumbnails: [
          ThumbnailFull(
            url: 'https://img.example/pl.jpg',
            width: 226,
            height: 226,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<PodcastDetailed>> searchPodcasts(
    String query, {
    int limit = 20,
  }) async {
    return [
      PodcastDetailed(
        type: 'PODCAST',
        browseId: 'MPSP_POD1',
        name: 'Song Exploder',
        author: 'Hrishikesh Hirway',
        thumbnails: [
          ThumbnailFull(
            url: 'https://img.example/pod.jpg',
            width: 226,
            height: 226,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<EpisodeDetailed>> searchEpisodes(
    String query, {
    int limit = 20,
  }) async {
    return [
      EpisodeDetailed(
        type: 'EPISODE',
        videoId: 'EP_VID_1',
        name: 'Snoh Aalegra Deep Dive',
        podcastName: 'Song Exploder',
        podcastId: 'MPSP_POD1',
        date: '2026-10-01',
        thumbnails: [
          ThumbnailFull(
            url: 'https://img.example/ep.jpg',
            width: 226,
            height: 226,
          ),
        ],
      ),
    ];
  }
}

class _ConcurrencyTrackingMusicRepo extends _FakeMusicRepo {
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<List<SongDetailed>> searchSongs(String query, {int limit = 20}) async {
    inFlight++;
    maxInFlight = max(maxInFlight, inFlight);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    inFlight--;
    return [
      SongDetailed(
        type: 'SONG',
        videoId: 'vid_$query',
        name: 'Song $query',
        artists: [ArtistBasic(name: 'HOME', artistId: 'UC_HOME')],
        album: AlbumBasic(albumId: 'MPRE_RES', name: 'Odyssey'),
        duration: 210,
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

    test('useTasteContext=false disables get_taste_profile, get_listening_history, search_local_library and get_local_playlist_tracks', () async {
      final lib = _FakeLibraryRepo()
        ..playlists = [
          LocalPlaylistModel(
            id: 1,
            name: 'Mix',
            createdAt: DateTime(2026, 1, 1),
          ),
        ];
      final executor = AskToolExecutor(
        libraryRepository: lib,
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
      final res3 = await executor.execute(
        const AskToolCall(
          id: '3',
          name: 'search_local_library',
          arguments: {'query': 'daft'},
        ),
      );
      final res4 = await executor.execute(
        const AskToolCall(
          id: '4',
          name: 'get_local_playlist_tracks',
          arguments: {'playlistId': 1},
        ),
      );

      expect(jsonDecode(res1.contentJson), {'disabledByUser': true});
      expect(jsonDecode(res2.contentJson), {'disabledByUser': true});
      expect(jsonDecode(res3.contentJson), {'disabledByUser': true});
      expect(jsonDecode(res4.contentJson), {'disabledByUser': true});
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

    test(
      'wrap-up round uses toolChoice=none when an attachment already exists',
      () async {
        final executor = AskToolExecutor(
          libraryRepository: _FakeLibraryRepo(),
          musicRepository: _FakeMusicRepo(),
        );
        final repo = _FakeChatRepo((round, messages, turnId) {
          if (round < 5) {
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
          if (round == 5) {
            return const LlmChatResponse(
              toolCalls: [
                AskToolCall(
                  id: 'call_mix',
                  name: 'propose_mix',
                  arguments: {
                    'title': 'Big Mix',
                    'videoIds': ['real_ytm_1'],
                  },
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
      },
    );

    test('proposal-only round fires after max tool rounds when entities were seen without attachments', () async {
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
        if (round == 6) {
          return const LlmChatResponse(
            toolCalls: [
              AskToolCall(
                id: 'call_prop',
                name: 'propose_mix',
                arguments: {
                  'title': 'Proposal Wrap',
                  'videoIds': ['real_ytm_1'],
                },
              ),
            ],
          );
        }
        return const LlmChatResponse(content: 'Ecco il tuo mix pronto.');
      });

      final res = await AskAgentUseCase(
        repo,
      ).execute(userMessage: 'fammi un mix', executor: executor, locale: 'it');

      expect(res.assistantText, 'Ecco il tuo mix pronto.');
      expect(res.attachments.single, isA<AskMixAttachment>());
      expect(repo.seenToolCounts, hasLength(8));
      expect(repo.seenToolCounts[6], executor.presentationDefinitions.length);
      expect(repo.seenToolChoices[6], 'auto');
      expect(repo.seenToolChoices[7], 'none');
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

    test('present_catalog_items validates all entity kinds and rejects unverified IDs', () async {
      final library = _FakeLibraryRepo()
        ..playlists = [
          LocalPlaylistModel(
            id: 40,
            name: 'R&B Notturno',
            description: 'Moody',
            createdAt: DateTime(2026, 11, 21),
          ),
        ];
      final executor = AskToolExecutor(
        libraryRepository: library,
        musicRepository: _FakeMusicRepo(),
      );

      await executor.execute(
        const AskToolCall(id: 't1', name: 'get_taste_profile', arguments: {}),
      );
      await executor.execute(
        const AskToolCall(
          id: 't2',
          name: 'search_catalog',
          arguments: {'query': 'x', 'type': 'songs'},
        ),
      );
      await executor.execute(
        const AskToolCall(
          id: 't3',
          name: 'search_catalog',
          arguments: {'query': 'x', 'type': 'artists'},
        ),
      );
      await executor.execute(
        const AskToolCall(
          id: 't4',
          name: 'search_catalog',
          arguments: {'query': 'x', 'type': 'albums'},
        ),
      );
      await executor.execute(
        const AskToolCall(
          id: 't5',
          name: 'search_catalog',
          arguments: {'query': 'x', 'type': 'playlists'},
        ),
      );
      await executor.execute(
        const AskToolCall(
          id: 't6',
          name: 'search_catalog',
          arguments: {'query': 'x', 'type': 'podcasts'},
        ),
      );
      await executor.execute(
        const AskToolCall(
          id: 't7',
          name: 'search_catalog',
          arguments: {'query': 'x', 'type': 'episodes'},
        ),
      );

      final presentRes = await executor.execute(
        const AskToolCall(
          id: 'p1',
          name: 'present_catalog_items',
          arguments: {
            'title': 'Consigli per te',
            'artistIds': ['UC_MEREBA', 'FAKE_ARTIST'],
            'trackVideoIds': ['real_ytm_1', 'FAKE_TRACK'],
            'albumIds': ['MPRE_SNOH', 'FAKE_ALBUM'],
            'playlistIds': ['RDCLAK_SOUL'],
            'localPlaylistIds': [40, 999],
            'podcastBrowseIds': ['MPSP_POD1'],
            'episodeVideoIds': ['EP_VID_1'],
          },
        ),
      );

      final summary =
          jsonDecode(presentRes.contentJson) as Map<String, dynamic>;
      expect(summary['ok'], isTrue);
      expect(summary['rejectedCount'], 4);

      expect(
        executor.attachments
            .whereType<AskArtistsAttachment>()
            .single
            .artists
            .single
            .artistId,
        'UC_MEREBA',
      );
      final track = executor.attachments
          .whereType<AskTracksAttachment>()
          .single
          .tracks
          .single;
      expect(track.videoId, 'real_ytm_1');
      expect(track.artistId, 'UC_HOME');
      expect(track.albumId, 'MPRE_RES');
      expect(track.albumName, 'Odyssey');
      expect(
        executor.attachments
            .whereType<AskAlbumsAttachment>()
            .single
            .albums
            .single
            .albumId,
        'MPRE_SNOH',
      );
      final playlists = executor.attachments
          .whereType<AskPlaylistsAttachment>()
          .single
          .playlists;
      expect(playlists, hasLength(2));
      expect(playlists.first.playlistId, 'RDCLAK_SOUL');
      expect(playlists.last.localPlaylistId, 40);
      expect(
        executor.attachments
            .whereType<AskPodcastsAttachment>()
            .single
            .podcasts
            .single
            .browseId,
        'MPSP_POD1',
      );
      expect(
        executor.attachments
            .whereType<AskEpisodesAttachment>()
            .single
            .episodes
            .single
            .videoId,
        'EP_VID_1',
      );
    });

    test('proposal-only round recovers early text-only playlist reply when verified tracks exist', () async {
      final executor = AskToolExecutor(
        libraryRepository: _FakeLibraryRepo(),
        musicRepository: _FakeMusicRepo(),
      );
      final repo = _FakeChatRepo((round, messages, turnId) {
        if (round == 0) {
          return const LlmChatResponse(
            toolCalls: [
              AskToolCall(id: 'tp', name: 'get_taste_profile', arguments: {}),
              AskToolCall(
                id: 'sc',
                name: 'search_catalog',
                arguments: {'query': 'rnb', 'type': 'songs'},
              ),
            ],
          );
        }
        if (round == 1) {
          // Simulates model replying in prose without calling propose_mix.
          return const LlmChatResponse(
            content: 'Ecco un elenco di tracce: Midnight City, Instant Crush, Resonance.',
          );
        }
        if (round == 2) {
          return const LlmChatResponse(
            toolCalls: [
              AskToolCall(
                id: 'pm',
                name: 'propose_mix',
                arguments: {
                  'title': 'Recovered Mix',
                  'videoIds': ['real_hist_1', 'real_liked_1', 'real_ytm_1'],
                },
              ),
            ],
          );
        }
        return const LlmChatResponse(
          content: 'Ecco il tuo mix pronto da ascoltare.',
        );
      });

      // Seed a 4th verified track in the turn before execution.
      executor.seenTracks['real_extra'] = const AskTrackRef(
        videoId: 'real_extra',
        title: 'Extra',
        artist: 'Artist',
      );

      final res = await AskAgentUseCase(repo).execute(
        userMessage: 'fammi una playlist sui miei gusti',
        executor: executor,
        locale: 'it',
      );

      expect(res.attachments.whereType<AskMixAttachment>(), hasLength(1));
      expect(res.assistantText, 'Ecco il tuo mix pronto da ascoltare.');
    });

    test('auto-grounding attaches mentioned artists and albums when model forgets present_catalog_items', () async {
      final executor = AskToolExecutor(
        libraryRepository: _FakeLibraryRepo(),
        musicRepository: _FakeMusicRepo(),
      );
      final repo = _FakeChatRepo((round, messages, turnId) {
        if (round == 0) {
          return const LlmChatResponse(
            toolCalls: [
              AskToolCall(
                id: 'a1',
                name: 'search_catalog',
                arguments: {'query': 'Mereba', 'type': 'artists'},
              ),
              AskToolCall(
                id: 'al1',
                name: 'search_catalog',
                arguments: {'query': 'Snoh', 'type': 'albums'},
              ),
            ],
          );
        }
        return const LlmChatResponse(
          content: 'Ti consiglio Mereba e l album Temporary Highs in the Violet Skies!',
        );
      });

      final res = await AskAgentUseCase(repo).execute(
        userMessage: 'consigliami un artista e un album simile',
        executor: executor,
        locale: 'it',
      );

      expect(
        res.attachments
            .whereType<AskArtistsAttachment>()
            .single
            .artists
            .single
            .artistId,
        'UC_MEREBA',
      );
      expect(
        res.attachments
            .whereType<AskAlbumsAttachment>()
            .single
            .albums
            .single
            .albumId,
        'MPRE_SNOH',
      );
    });

    test('throws AskEmptyResponseException when both assistantText and attachments are empty', () async {
      final executor = AskToolExecutor(
        libraryRepository: _FakeLibraryRepo(),
        musicRepository: _FakeMusicRepo(),
      );
      final repo = _FakeChatRepo((round, messages, turnId) {
        return const LlmChatResponse(content: '   ');
      });

      await expectLater(
        () =>
            AskAgentUseCase(repo)
                .execute(userMessage: 'ciao', executor: executor, locale: 'it'),
        throwsA(isA<AskEmptyResponseException>()),
      );
    });

    test('propose_playlist_write append deduplicates tracks already present in target local playlist', () async {
      final library = _FakeLibraryRepo()
        ..playlists = [
          LocalPlaylistModel(
            id: 40,
            name: 'R&B Notturno',
            createdAt: DateTime(2026, 11, 21),
          ),
        ]
        ..entriesByPlaylist = {
          40: [
            const PlaylistEntryModel(
              playlistId: 40,
              videoId: 'real_hist_1',
              position: 0,
              title: 'Midnight City',
              artist: 'M83',
            ),
          ],
        };
      final executor = AskToolExecutor(
        libraryRepository: library,
        musicRepository: _FakeMusicRepo(),
      );
      await executor.execute(
        const AskToolCall(
          id: 's1',
          name: 'search_catalog',
          arguments: {'query': 'home', 'type': 'songs'},
        ),
      );

      final res = await executor.execute(
        const AskToolCall(
          id: 'pw1',
          name: 'propose_playlist_write',
          arguments: {
            'operation': 'append',
            'playlistName': 'r&b notturno',
            'videoIds': ['real_hist_1', 'real_ytm_1'],
          },
        ),
      );

      final decoded = jsonDecode(res.contentJson) as Map<String, dynamic>;
      expect(decoded['ok'], isTrue);
      expect(decoded['existingCount'], 1);
      expect(decoded['trackCount'], 1);
      expect(decoded['resultingTotalTracks'], 2);
      expect(decoded['skippedAlreadyInPlaylist'], 1);

      final proposal = executor.attachments.single as AskPlaylistWriteProposal;
      expect(proposal.targetPlaylistId, 40);
      expect(proposal.playlistName, 'R&B Notturno');
      expect(proposal.tracks.map((t) => t.videoId), ['real_ytm_1']);
    });

    test('echoes reasoningContent and serverToolCalls across rounds and uses 4096 maxOutputTokens when enableWebSearch is true', () async {
      final executor = AskToolExecutor(
        libraryRepository: _FakeLibraryRepo(),
        musicRepository: _FakeMusicRepo(),
      );
      late List<LlmChatMessage> secondRoundMessages;
      final repo = _FakeChatRepo((round, messages, turnId) {
        if (round == 0) {
          return const LlmChatResponse(
            toolCalls: [
              AskToolCall(
                id: 'sc',
                name: 'search_catalog',
                arguments: {'query': 'Tanerelle', 'type': 'artists'},
              ),
            ],
            reasoningContent: 'Searching artist profile and web',
            serverToolCalls: [
              {'type': 'web_search', 'query': 'Tanerelle biography'},
            ],
          );
        }
        secondRoundMessages = List.of(messages);
        return const LlmChatResponse(content: 'Ecco tutto su Tanerelle!');
      });

      final res = await AskAgentUseCase(repo).execute(
        userMessage: 'Dimmi qualcosa in piu su Tanerelle',
        executor: executor,
        locale: 'it',
        enableWebSearch: true,
      );

      expect(res.assistantText, 'Ecco tutto su Tanerelle!');
      expect(repo.seenMaxOutputTokens, [4096, 4096]);
      final assistantMsg = secondRoundMessages.singleWhere(
        (m) => m.role == 'assistant' && m.toolCalls.isNotEmpty,
      );
      expect(assistantMsg.reasoningContent, 'Searching artist profile and web');
      expect(assistantMsg.serverToolCalls, [
        {'type': 'web_search', 'query': 'Tanerelle biography'},
      ]);
    });

    test('executes read-only tools in parallel (capped at 4) before presentation tools and preserves tool_call_id order', () async {
      final music = _ConcurrencyTrackingMusicRepo();
      final executor = AskToolExecutor(
        libraryRepository: _FakeLibraryRepo(),
        musicRepository: music,
      );
      late List<LlmChatMessage> secondRoundMessages;
      final repo = _FakeChatRepo((round, messages, turnId) {
        if (round == 0) {
          return const LlmChatResponse(
            toolCalls: [
              AskToolCall(
                id: 'c0',
                name: 'search_catalog',
                arguments: {'query': 'q0', 'type': 'songs'},
              ),
              AskToolCall(
                id: 'c1',
                name: 'propose_mix',
                arguments: {
                  'title': 'Parallel Mix',
                  'videoIds': ['vid_q0', 'vid_q3', 'vid_q6'],
                },
              ),
              AskToolCall(
                id: 'c2',
                name: 'search_catalog',
                arguments: {'query': 'q2', 'type': 'songs'},
              ),
              AskToolCall(
                id: 'c3',
                name: 'search_catalog',
                arguments: {'query': 'q3', 'type': 'songs'},
              ),
              AskToolCall(
                id: 'c4',
                name: 'search_catalog',
                arguments: {'query': 'q4', 'type': 'songs'},
              ),
              AskToolCall(
                id: 'c5',
                name: 'search_catalog',
                arguments: {'query': 'q5', 'type': 'songs'},
              ),
              AskToolCall(
                id: 'c6',
                name: 'search_catalog',
                arguments: {'query': 'q6', 'type': 'songs'},
              ),
            ],
          );
        }
        secondRoundMessages = List.of(messages);
        return const LlmChatResponse(content: 'Pronto!');
      });

      final res = await AskAgentUseCase(
        repo,
      ).execute(userMessage: 'fammi un mix', executor: executor, locale: 'it');

      expect(music.maxInFlight, greaterThan(1));
      expect(music.maxInFlight, lessThanOrEqualTo(4));
      final mix = res.attachments.single as AskMixAttachment;
      expect(mix.tracks.map((t) => t.videoId), ['vid_q0', 'vid_q3', 'vid_q6']);

      final toolIds = secondRoundMessages
          .where((m) => m.role == 'tool')
          .map((m) => m.toolCallId)
          .toList();
      expect(toolIds, ['c0', 'c1', 'c2', 'c3', 'c4', 'c5', 'c6']);
    });

    test('reports ordered AskProgressPhase transitions across search, proposal, and final wrap-up', () async {
      final executor = AskToolExecutor(
        libraryRepository: _FakeLibraryRepo(),
        musicRepository: _FakeMusicRepo(),
      );
      final repo = _FakeChatRepo((round, messages, turnId) {
        if (round < 5) {
          return LlmChatResponse(
            toolCalls: [
              AskToolCall(
                id: 's_$round',
                name: 'search_catalog',
                arguments: {'query': 'q$round', 'type': 'songs'},
              ),
            ],
          );
        }
        if (round == 5) {
          return const LlmChatResponse(
            toolCalls: [
              AskToolCall(
                id: 'pm',
                name: 'propose_mix',
                arguments: {
                  'title': 'Phased Mix',
                  'videoIds': ['real_ytm_1'],
                },
              ),
            ],
          );
        }
        return const LlmChatResponse(content: 'Ecco il mix.');
      });

      final phases = <AskProgressPhase>[];
      await AskAgentUseCase(repo).execute(
        userMessage: 'fammi un mix',
        executor: executor,
        locale: 'it',
        onProgress: (p) {
          if (phases.isEmpty || phases.last != p) {
            phases.add(p);
          }
        },
      );

      expect(phases, [
        AskProgressPhase.thinking,
        AskProgressPhase.searchingCatalog,
        AskProgressPhase.buildingProposal,
        AskProgressPhase.finalizing,
      ]);
    });

    test('throws AskCancelledException and aborts before running subsequent tools or rounds', () async {
      final music = _ConcurrencyTrackingMusicRepo();
      final executor = AskToolExecutor(
        libraryRepository: _FakeLibraryRepo(),
        musicRepository: music,
      );
      var cancelled = false;
      var repoCalls = 0;
      final repo = _FakeChatRepo((round, messages, turnId) {
        repoCalls++;
        cancelled = true;
        return const LlmChatResponse(
          toolCalls: [
            AskToolCall(
              id: 'c1',
              name: 'search_catalog',
              arguments: {'query': 'abc', 'type': 'songs'},
            ),
          ],
        );
      });

      await expectLater(
        () => AskAgentUseCase(repo).execute(
          userMessage: 'cerca qualcosa',
          executor: executor,
          locale: 'it',
          isCancelled: () => cancelled,
        ),
        throwsA(isA<AskCancelledException>()),
      );

      expect(repoCalls, 1);
      expect(music.maxInFlight, 0);
    });
  });
}

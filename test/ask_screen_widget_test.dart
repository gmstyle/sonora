import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/domain/models/ask_capabilities.dart';
import 'package:sonora/domain/models/ask_chat_models.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/domain/repositories/ask_storage_repository.dart';
import 'package:sonora/domain/repositories/library_repository.dart';
import 'package:sonora/domain/repositories/llm_chat_repository.dart';
import 'package:sonora/domain/repositories/music_repository.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/ask/ask_screen.dart';
import 'package:sonora/presentation/features/ask/providers/ask_chat_provider.dart';
import 'package:sonora/presentation/features/ask/widgets/ask_composer.dart';
import 'package:sonora/presentation/features/ask/widgets/ask_drops_section.dart';
import 'package:sonora/presentation/features/ask/widgets/ask_follow_up_chips.dart';
import 'package:sonora/presentation/features/ask/widgets/ask_guided_actions.dart';
import 'package:sonora/presentation/features/player/player_sheet_mobile.dart';
import 'package:sonora/presentation/features/tv/layouts/tv_shell.dart';
import 'package:sonora/presentation/features/tv/tv_metrics.dart';
import 'package:sonora/presentation/providers/android_tv_provider.dart';
import 'package:sonora/presentation/providers/ask_llm_provider.dart';
import 'package:sonora/presentation/providers/ask_storage_provider.dart';
import 'package:sonora/presentation/providers/connectivity_provider.dart';
import 'package:sonora/presentation/providers/download_provider.dart';
import 'package:sonora/presentation/providers/library_repository_provider.dart';
import 'package:sonora/presentation/providers/music_repository_provider.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/playlist_import_job_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';
import 'package:sonora/presentation/shared/layouts/mobile_shell.dart';
import 'package:sonora/presentation/shared/widgets/action_feedback_listener.dart';
import 'package:sonora/presentation/shared/widgets/album_card.dart';
import 'package:sonora/presentation/shared/widgets/artist_card.dart';
import 'package:sonora/presentation/shared/widgets/context_menu/artist_context_menu.dart';
import 'package:sonora/presentation/shared/widgets/context_menu/custom_playlist_context_menu.dart';
import 'package:sonora/presentation/shared/widgets/context_menu/song_context_menu.dart';
import 'package:sonora/presentation/shared/widgets/episode_tile.dart';
import 'package:sonora/presentation/shared/widgets/feedback_toast.dart';
import 'package:sonora/presentation/shared/widgets/playlist_card.dart';
import 'package:sonora/presentation/shared/widgets/podcast_tile.dart';
import 'package:sonora/presentation/shared/widgets/song_tile.dart';

class _FakePlayer extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

class _FakePlayingPlayer extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState(
    currentSong: MediaItem(
      id: 'vid_mobile',
      title: 'Midnight City',
      artist: 'M83',
      duration: Duration(minutes: 4),
    ),
  );
}

class _FakeLibraryRepo extends Fake implements LibraryRepository {
  final List<LocalPlaylistModel> playlists = [];
  final List<String> createdNames = [];
  int createCalls = 0;
  int _nextId = 1;

  @override
  Future<List<LocalPlaylistModel>> getAllPlaylists() async =>
      List.unmodifiable(playlists);

  @override
  Stream<List<LocalPlaylistModel>> watchAllPlaylists() =>
      Stream.value(List.unmodifiable(playlists));

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
    createCalls++;
    createdNames.add(name);
    final id = _nextId++;
    playlists.add(
      LocalPlaylistModel(
        id: id,
        name: name,
        description: description,
        createdAt: DateTime(2026, 11, 21),
        sourceKind: sourceKind,
        remoteId: remoteId,
        remoteName: remoteName,
        lastSyncedAt: lastSyncedAt,
        linkStatus: linkStatus,
      ),
    );
    return id;
  }

  @override
  Future<LocalPlaylistModel?> getPlaylist(int id) async {
    for (final p in playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<List<PlaylistEntryModel>> getPlaylistEntries(int playlistId) async =>
      const [];

  @override
  Stream<List<PlaylistEntryModel>> watchPlaylistEntries(int playlistId) =>
      Stream.value(const []);

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
  }) async {}

  @override
  Stream<LikedSongModel?> watchLikedSong(String videoId) => Stream.value(null);

  @override
  Stream<FollowedArtistModel?> watchFollowedArtist(String artistId) =>
      Stream.value(null);

  @override
  Future<void> updateLikedSongMetadata(
    String videoId, {
    String? artistId,
    String? albumId,
    String? artistsJson,
  }) async {}
}

class _FakeAskStorageRepo extends Fake implements AskStorageRepository {
  _FakeAskStorageRepo({
    List<AskConversationSummary>? conversations,
    Map<String, List<AskChatMessage>>? messagesByConv,
    List<AskProactiveDrop>? drops,
  }) : _conversations = List.of(conversations ?? const []),
       _messagesByConv = {
         if (messagesByConv != null)
           for (final e in messagesByConv.entries) e.key: List.of(e.value),
       },
       _drops = List.of(drops ?? const []);

  final List<AskConversationSummary> _conversations;
  final Map<String, List<AskChatMessage>> _messagesByConv;
  final List<AskProactiveDrop> _drops;

  final _convCtrl = StreamController<List<AskConversationSummary>>.broadcast();
  final _dropsCtrl = StreamController<List<AskProactiveDrop>>.broadcast();
  final Map<String, StreamController<List<AskChatMessage>>> _msgCtrls = {};

  StreamController<List<AskChatMessage>> _msgController(String convId) =>
      _msgCtrls.putIfAbsent(convId, () => StreamController.broadcast());

  void dispose() {
    unawaited(_convCtrl.close());
    unawaited(_dropsCtrl.close());
    for (final c in _msgCtrls.values) {
      unawaited(c.close());
    }
  }

  @override
  Stream<List<AskConversationSummary>> watchConversations() async* {
    yield List.unmodifiable(_conversations);
    yield* _convCtrl.stream;
  }

  @override
  Future<List<AskConversationSummary>> getConversations() async =>
      List.unmodifiable(_conversations);

  @override
  Future<void> upsertConversation(AskConversationSummary conversation) async {
    final idx = _conversations.indexWhere((c) => c.id == conversation.id);
    if (idx >= 0) {
      _conversations[idx] = conversation;
    } else {
      _conversations.insert(0, conversation);
    }
    if (!_convCtrl.isClosed) {
      _convCtrl.add(List.unmodifiable(_conversations));
    }
  }

  @override
  Future<void> clearAllConversations() async {
    _conversations.clear();
    _messagesByConv.clear();
    if (!_convCtrl.isClosed) {
      _convCtrl.add(const []);
    }
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    _conversations.removeWhere((c) => c.id == conversationId);
    _messagesByConv.remove(conversationId);
    if (!_convCtrl.isClosed) {
      _convCtrl.add(List.unmodifiable(_conversations));
    }
    final ctrl = _msgController(conversationId);
    if (!ctrl.isClosed) {
      ctrl.add(const []);
    }
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    for (final entry in _messagesByConv.entries) {
      final before = entry.value.length;
      entry.value.removeWhere((m) => m.id == messageId);
      if (entry.value.length == before) continue;
      final ctrl = _msgController(entry.key);
      if (!ctrl.isClosed) {
        ctrl.add(List.unmodifiable(entry.value));
      }
      return;
    }
  }

  @override
  Future<void> insertMessage(AskChatMessage message) async {
    final list = _messagesByConv.putIfAbsent(message.conversationId, () => []);
    list.add(message);
    final ctrl = _msgController(message.conversationId);
    if (!ctrl.isClosed) {
      ctrl.add(List.unmodifiable(list));
    }
  }

  @override
  Stream<List<AskChatMessage>> watchMessages(String conversationId) async* {
    yield List.unmodifiable(_messagesByConv[conversationId] ?? const []);
    yield* _msgController(conversationId).stream;
  }

  @override
  Future<List<AskChatMessage>> getMessages(String conversationId) async =>
      List.unmodifiable(_messagesByConv[conversationId] ?? const []);

  @override
  Future<void> updateMessageAttachments(
    String messageId,
    List<AskAttachment> attachments,
  ) async {
    for (final entry in _messagesByConv.entries) {
      final idx = entry.value.indexWhere((m) => m.id == messageId);
      if (idx >= 0) {
        final old = entry.value[idx];
        entry.value[idx] = AskChatMessage(
          id: old.id,
          conversationId: old.conversationId,
          role: old.role,
          content: old.content,
          attachments: attachments,
          toolNamesUsed: old.toolNamesUsed,
          createdAt: old.createdAt,
          isError: old.isError,
        );
        _msgController(entry.key).add(List.unmodifiable(entry.value));
        return;
      }
    }
  }

  @override
  Stream<List<AskProactiveDrop>> watchActiveDrops() async* {
    yield List.unmodifiable(_drops.where((d) => d.dismissedAt == null));
    yield* _dropsCtrl.stream;
  }

  @override
  Future<List<AskProactiveDrop>> getActiveDrops() async =>
      List.unmodifiable(_drops.where((d) => d.dismissedAt == null));

  List<AskChatMessage> messagesFor(String convId) =>
      _messagesByConv[convId] ?? const [];
}

class _FakeWidgetMusicRepo extends Fake implements MusicRepository {
  @override
  Future<List<SongDetailed>> searchSongs(
    String query, {
    int limit = 20,
  }) async => const [];

  @override
  Future<SongFull> getSong(String videoId) async {
    return SongFull(
      type: 'SONG',
      videoId: videoId,
      name: 'Midnight City',
      artists: [ArtistBasic(artistId: 'UC_M83', name: 'M83')],
      duration: 244,
      thumbnails: const [],
      formats: const [],
      adaptiveFormats: const [],
    );
  }
}

class _CallbackChatRepo implements LlmChatRepository {
  _CallbackChatRepo(
    this.onComplete, {
    this.quota = const AskQuotaInfo(remaining: 30, limit: 30),
  });

  final AskQuotaInfo quota;
  final Future<LlmChatResponse> Function(
    int callIndex,
    List<LlmChatMessage> messages,
  )
  onComplete;
  int _calls = 0;

  @override
  Future<bool> isReady() async => true;

  @override
  Future<AskQuotaInfo?> fetchQuota() async => quota;

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
  }) => onComplete(_calls++, messages);
}

Future<AppLocalizations> _pumpAskScreen(
  WidgetTester tester, {
  required Size size,
  bool offline = false,
  String? initialPrompt,
  _FakeAskStorageRepo? storage,
  _FakeLibraryRepo? library,
  LlmChatRepository? chatRepo,
  MusicRepository? musicRepo,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(FeedbackToast.dismiss);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fakeStorage = storage ?? _FakeAskStorageRepo();
  if (storage == null) addTearDown(fakeStorage.dispose);
  final fakeLib = library ?? _FakeLibraryRepo();
  final fakeMusic = musicRepo ?? _FakeWidgetMusicRepo();
  final effectiveChatRepo =
      chatRepo ??
      _CallbackChatRepo((_, _) async => const LlmChatResponse(content: 'Ok'));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isOfflineProvider.overrideWithValue(offline),
        isAndroidTvProvider.overrideWithValue(false),
        askCapabilitiesProvider.overrideWith(
          (_) async => AskCapabilities(
            backend: AskBackendMode.proxy,
            isOffline: offline,
          ),
        ),
        askStorageRepositoryProvider.overrideWithValue(fakeStorage),
        libraryRepositoryProvider.overrideWithValue(fakeLib),
        musicRepositoryProvider.overrideWithValue(fakeMusic),
        playerStateProvider.overrideWith(_FakePlayer.new),
        askChatRepositoryProvider.overrideWithValue(effectiveChatRepo),
        downloadedIdsProvider.overrideWithValue(const {}),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Stack(
          children: [
            AskScreen(initialPrompt: initialPrompt),
            const ActionFeedbackListener(),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(AskScreen)))!;
}

void main() {
  testWidgets(
    'compact layout renders guided actions, composer, quota badge, and history button without overflow',
    (tester) async {
      final dropsRepo = _FakeAskStorageRepo(
        drops: [
          AskProactiveDrop(
            id: 'd1',
            kind: 'heavy_rotation',
            title: 'M83 Heavy Rotation',
            body: 'You spun M83 ten times this week.',
            starterPrompt: 'Build a dreamy M83 mix',
            createdAt: DateTime(2026, 11, 21),
          ),
        ],
      );
      addTearDown(dropsRepo.dispose);

      final l10n = await _pumpAskScreen(
        tester,
        size: const Size(400, 800),
        storage: dropsRepo,
      );

      expect(find.text(l10n.askHubTitle), findsOneWidget);
      expect(find.text(l10n.askWelcomeTitle), findsOneWidget);
      expect(find.byType(AskGuidedActions), findsOneWidget);
      expect(find.byType(AskDropsSection), findsOneWidget);
      expect(find.byType(AskComposer), findsOneWidget);
      expect(find.text(l10n.askGuidedMixTitle), findsOneWidget);
      expect(find.text(l10n.askGuidedDiscoverTitle), findsOneWidget);
      expect(find.text(l10n.askQuotaBadge(30, 30)), findsOneWidget);
      expect(find.byIcon(LucideIcons.history), findsOneWidget);
      expect(find.text('M83 Heavy Rotation'), findsOneWidget);
    },
  );

  testWidgets(
    'wide layout renders sidebar rail, history list, and utility rail Pulse Drops without overflow',
    (tester) async {
      final storage = _FakeAskStorageRepo(
        conversations: [
          AskConversationSummary(
            id: 'c1',
            title: 'Chill Synth Session',
            createdAt: DateTime(2026, 11, 20),
            updatedAt: DateTime(2026, 11, 21),
          ),
        ],
        drops: [
          AskProactiveDrop(
            id: 'd1',
            kind: 'forgotten_favorites',
            title: 'Forgotten Gems',
            body: 'Revisit 5 tracks you loved last month.',
            starterPrompt: 'Play my forgotten gems',
            createdAt: DateTime(2026, 11, 21),
          ),
        ],
      );
      addTearDown(storage.dispose);

      final l10n = await _pumpAskScreen(
        tester,
        size: const Size(1680, 900),
        storage: storage,
      );

      expect(find.text(l10n.askNewChat), findsOneWidget);
      expect(find.text('Chill Synth Session'), findsOneWidget);
      expect(find.text(l10n.askDropsHeader), findsOneWidget);
      expect(find.text('Forgotten Gems'), findsOneWidget);
      expect(find.byType(AskComposer), findsOneWidget);
    },
  );

  testWidgets(
    'offline mode disables composer field, submit button, and guided actions',
    (tester) async {
      final l10n = await _pumpAskScreen(
        tester,
        size: const Size(400, 800),
        offline: true,
      );

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.enabled, isFalse);

      final submitBtn = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(submitBtn.onPressed, isNull);

      final mixChip = tester.widget<ActionChip>(
        find.widgetWithText(ActionChip, l10n.askGuidedMixTitle),
      );
      expect(mixChip.onPressed, isNull);
    },
  );

  testWidgets(
    'Safe Write proposals require explicit Confirm & save or Discard before writing playlists',
    (tester) async {
      final lib = _FakeLibraryRepo();
      const t1 = AskTrackRef(
        videoId: 'v1',
        title: 'Track 1',
        artist: 'Artist A',
      );
      const t2 = AskTrackRef(
        videoId: 'v2',
        title: 'Track 2',
        artist: 'Artist B',
      );

      final storage = _FakeAskStorageRepo(
        conversations: [
          AskConversationSummary(
            id: 'conv_1',
            title: 'Playlist Draft',
            createdAt: DateTime(2026, 11, 21),
            updatedAt: DateTime(2026, 11, 21),
          ),
        ],
        messagesByConv: {
          'conv_1': [
            AskChatMessage(
              id: 'msg_1',
              conversationId: 'conv_1',
              role: 'assistant',
              content: 'Here are two playlist options.',
              attachments: const [
                AskPlaylistWriteProposal(
                  operation: 'create',
                  playlistName: 'Night Synth',
                  tracks: [t1],
                ),
                AskPlaylistWriteProposal(
                  operation: 'create',
                  playlistName: 'Skip Me',
                  tracks: [t2],
                ),
              ],
              createdAt: DateTime(2026, 11, 21),
            ),
          ],
        },
      );
      addTearDown(storage.dispose);

      final l10n = await _pumpAskScreen(
        tester,
        size: const Size(1680, 900),
        storage: storage,
        library: lib,
      );

      await tester.tap(find.text('Playlist Draft'));
      await tester.pumpAndSettle();

      expect(find.text('Night Synth'), findsOneWidget);
      expect(find.text('Skip Me'), findsOneWidget);
      expect(lib.createCalls, 0);

      await tester.tap(find.text(l10n.askActionConfirmSave).first);
      await tester.pumpAndSettle();

      expect(lib.createCalls, 1);
      expect(lib.createdNames, ['Night Synth']);
      expect(find.text(l10n.askSavedStatus), findsOneWidget);

      final savedAtt =
          storage.messagesFor('conv_1').single.attachments[0]
              as AskPlaylistWriteProposal;
      expect(savedAtt.status, 'saved');
      expect(savedAtt.savedPlaylistId, 1);

      await tester.tap(find.text(l10n.askActionDiscard).first);
      await tester.pumpAndSettle();

      expect(lib.createCalls, 1);
      expect(find.text(l10n.askDiscardedStatus), findsOneWidget);
      final discardedAtt =
          storage.messagesFor('conv_1').single.attachments[1]
              as AskPlaylistWriteProposal;
      expect(discardedAtt.status, 'discarded');

      FeedbackToast.dismiss();
      await tester.pump();
    },
  );

  testWidgets('TvShell hides Ask destination and keeps 4 navigation items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(
      TvMetrics.designWidth,
      TvMetrics.designHeight,
    );
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => TvShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/search', builder: (_, _) => const SizedBox()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/library', builder: (_, _) => const SizedBox()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/downloads',
                  builder: (_, _) => const SizedBox(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    SharedPreferences.setMockInitialValues({kReduceEffectsKey: true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isAndroidTvProvider.overrideWithValue(true),
          playerStateProvider.overrideWith(_FakePlayer.new),
          downloadBannerSummaryProvider.overrideWithValue(null),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(find.byType(TvShell)))!;
    expect(find.byIcon(LucideIcons.home), findsOneWidget);
    expect(find.byIcon(LucideIcons.search), findsOneWidget);
    expect(find.byIcon(LucideIcons.library), findsOneWidget);
    expect(find.byIcon(LucideIcons.download), findsOneWidget);
    expect(find.byIcon(LucideIcons.sparkles), findsNothing);
    expect(find.text(l10n.askNavLabel), findsNothing);
  });

  testWidgets(
    'assistant replies render formatted Markdown via GptMarkdown without LaTeX dollar parsing',
    (tester) async {
      const reply = '''### Listening Profile

- **Top Artist**: A\$AP Rocky & Ty Dolla \$ign
- _Vibe_: Nocturnal hip-hop

> Check [YouTube Music](https://music.youtube.com) for more.''';

      final storage = _FakeAskStorageRepo(
        conversations: [
          AskConversationSummary(
            id: 'conv_md',
            title: 'Taste Profile',
            createdAt: DateTime(2026, 11, 21),
            updatedAt: DateTime(2026, 11, 21),
          ),
        ],
        messagesByConv: {
          'conv_md': [
            AskChatMessage(
              id: 'msg_md',
              conversationId: 'conv_md',
              role: 'assistant',
              content: reply,
              createdAt: DateTime(2026, 11, 21),
            ),
          ],
        },
      );
      addTearDown(storage.dispose);

      await _pumpAskScreen(
        tester,
        size: const Size(1680, 900),
        storage: storage,
      );

      await tester.tap(find.text('Taste Profile'));
      await tester.pumpAndSettle();

      final mdWidget = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(mdWidget.useDollarSignsForLatex, isFalse);
      expect(mdWidget.isStreaming, isFalse);
      expect(
        find.textContaining('Listening Profile', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('A\$AP Rocky', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Ty Dolla \$ign', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('**Top Artist**', findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining('### Listening', findRichText: true),
        findsNothing,
      );
    },
  );

  testWidgets(
    'AskMixCard and AskPlaylistProposalCard render expandable native SongTiles, menu button, and Open Playlist action',
    (tester) async {
      final lib = _FakeLibraryRepo();
      final tracks = [
        for (var i = 0; i < 8; i++)
          AskTrackRef(
            videoId: 'v_$i',
            title: 'Song Title $i',
            artist: 'Artist $i',
            artistId: 'UC_$i',
            albumId: 'MPRE_$i',
            albumName: 'Album $i',
          ),
      ];
      final storage = _FakeAskStorageRepo(
        conversations: [
          AskConversationSummary(
            id: 'conv_expand',
            title: 'Expand Mix',
            createdAt: DateTime(2026, 11, 21),
            updatedAt: DateTime(2026, 11, 21),
          ),
        ],
        messagesByConv: {
          'conv_expand': [
            AskChatMessage(
              id: 'msg_expand',
              conversationId: 'conv_expand',
              role: 'assistant',
              content: 'Mix ready.',
              attachments: [
                AskMixAttachment(title: 'Deep Night Mix', tracks: tracks),
                AskPlaylistWriteProposal(
                  operation: 'create',
                  playlistName: 'Saved Night Mix',
                  tracks: [tracks.first],
                  status: 'saved',
                  savedPlaylistId: 40,
                ),
              ],
              createdAt: DateTime(2026, 11, 21),
            ),
          ],
        },
      );
      addTearDown(storage.dispose);

      final l10n = await _pumpAskScreen(
        tester,
        size: const Size(1680, 900),
        storage: storage,
        library: lib,
      );

      await tester.tap(find.text('Expand Mix'));
      await tester.pumpAndSettle();

      // Mix shows first 6 + 1 saved proposal track = 7 SongTiles before expand.
      expect(find.byType(SongTile), findsNWidgets(7));
      expect(find.text('Song Title 7'), findsNothing);
      expect(find.text(l10n.askShowAllTracks(8)), findsOneWidget);
      expect(find.text(l10n.askActionQueue), findsOneWidget);
      expect(find.text(l10n.askActionOpenPlaylist), findsOneWidget);
      expect(find.byIcon(LucideIcons.ellipsisVertical), findsWidgets);

      await tester.ensureVisible(find.text(l10n.askShowAllTracks(8)));
      await tester.tap(find.text(l10n.askShowAllTracks(8)));
      await tester.pumpAndSettle();

      expect(find.text('Song Title 7'), findsOneWidget);
      expect(find.byType(SongTile), findsNWidgets(9));
      expect(find.text(l10n.askShowLessTracks), findsOneWidget);
    },
  );

  testWidgets(
    'native ArtistCard, AlbumCard, PlaylistCard, PodcastTile and EpisodeTile render across multiple messages without Hero collision',
    (tester) async {
      const sharedArtist = AskArtistRef(
        artistId: 'UC_TAN',
        name: 'Tanerélle',
        monthlyListeners: '800K',
      );
      const sharedAlbum = AskAlbumRef(
        albumId: 'MPRE_1',
        name: 'After Hours',
        artist: 'The Weeknd',
        year: 2020,
      );
      const sharedRemotePlaylist = AskPlaylistRef(
        playlistId: 'RDCLAK_1',
        name: 'Moody R&B',
        artist: 'YouTube Music',
      );
      const sharedLocalPlaylist = AskPlaylistRef(
        localPlaylistId: 40,
        name: 'R&B Notturno',
      );
      const podcast = AskPodcastRef(
        browseId: 'MPSP_1',
        name: 'Song Exploder',
        author: 'Hrishikesh Hirway',
      );
      const episode = AskEpisodeRef(
        videoId: 'EP_1',
        name: 'Behind the Beat',
        podcastName: 'Song Exploder',
        podcastBrowseId: 'MPSP_1',
        date: '2026-10-01',
      );

      final storage = _FakeAskStorageRepo(
        conversations: [
          AskConversationSummary(
            id: 'conv_native',
            title: 'Catalog Widgets',
            createdAt: DateTime(2026, 11, 21),
            updatedAt: DateTime(2026, 11, 21),
          ),
        ],
        messagesByConv: {
          'conv_native': [
            AskChatMessage(
              id: 'msg_1',
              conversationId: 'conv_native',
              role: 'assistant',
              content: 'First batch',
              attachments: const [
                AskArtistsAttachment(
                  title: 'Artists 1',
                  artists: [sharedArtist],
                ),
                AskAlbumsAttachment(title: 'Albums 1', albums: [sharedAlbum]),
                AskPlaylistsAttachment(
                  title: 'Playlists 1',
                  playlists: [sharedRemotePlaylist, sharedLocalPlaylist],
                ),
              ],
              createdAt: DateTime(2026, 11, 21, 10, 0),
            ),
            AskChatMessage(
              id: 'msg_2',
              conversationId: 'conv_native',
              role: 'assistant',
              content: 'Second batch',
              attachments: const [
                AskArtistsAttachment(
                  title: 'Artists 2',
                  artists: [sharedArtist],
                ),
                AskAlbumsAttachment(title: 'Albums 2', albums: [sharedAlbum]),
                AskPlaylistsAttachment(
                  title: 'Playlists 2',
                  playlists: [sharedRemotePlaylist],
                ),
                AskPodcastsAttachment(title: 'Podcasts', podcasts: [podcast]),
                AskEpisodesAttachment(title: 'Episodes', episodes: [episode]),
              ],
              createdAt: DateTime(2026, 11, 21, 10, 1),
            ),
          ],
        },
      );
      addTearDown(storage.dispose);

      await _pumpAskScreen(
        tester,
        size: const Size(1680, 2600),
        storage: storage,
      );

      await tester.tap(find.text('Catalog Widgets'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ArtistCard), findsNWidgets(2));
      expect(find.byType(AlbumCard), findsNWidgets(2));
      expect(find.byType(PlaylistCard), findsNWidgets(3));
      expect(find.byType(PodcastTile), findsOneWidget);
      expect(find.byType(EpisodeTile), findsOneWidget);
      final heroTags = tester
          .widgetList<Hero>(find.byType(Hero))
          .map((h) => h.tag)
          .toList();
      expect(heroTags.toSet(), hasLength(heroTags.length));
    },
  );

  testWidgets(
    'AskFollowUpChips render contextually for Mix and Artists and disable when offline',
    (tester) async {
      const mix = AskMixAttachment(
        title: 'Late Night R&B',
        tracks: [
          AskTrackRef(videoId: 'v1', title: 'Calls', artist: 'Tanerelle'),
        ],
      );
      const artists = AskArtistsAttachment(
        title: 'Artists',
        artists: [AskArtistRef(artistId: 'UC_1', name: 'Tanerelle')],
      );

      _FakeAskStorageRepo buildStorage() => _FakeAskStorageRepo(
        conversations: [
          AskConversationSummary(
            id: 'c_mix',
            title: 'Mix Conv',
            createdAt: DateTime(2026, 11, 22),
            updatedAt: DateTime(2026, 11, 22),
          ),
          AskConversationSummary(
            id: 'c_art',
            title: 'Artists Conv',
            createdAt: DateTime(2026, 11, 22),
            updatedAt: DateTime(2026, 11, 22),
          ),
        ],
        messagesByConv: {
          'c_mix': [
            AskChatMessage(
              id: 'm1',
              conversationId: 'c_mix',
              role: 'assistant',
              content: 'Here is your mix.',
              attachments: const [mix],
              createdAt: DateTime(2026, 11, 22),
            ),
          ],
          'c_art': [
            AskChatMessage(
              id: 'm2',
              conversationId: 'c_art',
              role: 'assistant',
              content: 'Check these artists.',
              attachments: const [artists],
              createdAt: DateTime(2026, 11, 22),
            ),
          ],
        },
      );

      final onlineStorage = buildStorage();
      addTearDown(onlineStorage.dispose);
      final l10n = await _pumpAskScreen(
        tester,
        size: const Size(1680, 900),
        storage: onlineStorage,
      );

      await tester.tap(find.text('Mix Conv'));
      await tester.pumpAndSettle();
      expect(find.byType(AskFollowUpChips), findsOneWidget);
      expect(find.text(l10n.askFollowUpExpand40), findsOneWidget);
      expect(find.text(l10n.askFollowUpCalmer), findsOneWidget);
      expect(find.text(l10n.askFollowUpEnergetic), findsOneWidget);

      await tester.tap(find.text('Artists Conv'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.askFollowUpMixArtists), findsOneWidget);
      expect(find.text(l10n.askFollowUpBestAlbums), findsOneWidget);
      expect(find.text(l10n.askFollowUpSimilarArtists), findsOneWidget);

      final offlineStorage = buildStorage();
      addTearDown(offlineStorage.dispose);
      await _pumpAskScreen(
        tester,
        size: const Size(1680, 900),
        offline: true,
        storage: offlineStorage,
      );
      await tester.tap(find.text('Mix Conv'));
      await tester.pumpAndSettle();

      final offlineChip = tester.widget<ActionChip>(
        find.widgetWithText(ActionChip, l10n.askFollowUpExpand40),
      );
      expect(offlineChip.onPressed, isNull);
    },
  );

  testWidgets(
    'live progressPhase label and Stop button cancel an in-flight turn cleanly',
    (tester) async {
      final round1Completer = Completer<LlmChatResponse>();
      final chatRepo = _CallbackChatRepo((callIdx, messages) {
        if (callIdx == 0) {
          return Future.value(
            const LlmChatResponse(
              toolCalls: [
                AskToolCall(
                  id: 'tc_1',
                  name: 'search_catalog',
                  arguments: {'query': 'Tanerelle', 'type': 'songs'},
                ),
              ],
            ),
          );
        }
        return round1Completer.future;
      });
      final storage = _FakeAskStorageRepo();
      addTearDown(storage.dispose);

      final l10n = await _pumpAskScreen(
        tester,
        size: const Size(400, 800),
        storage: storage,
        chatRepo: chatRepo,
      );

      await tester.enterText(find.byType(TextField), 'Mix per la sera');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text(l10n.askProgressSearchingCatalog), findsOneWidget);
      expect(find.byTooltip(l10n.askStop), findsOneWidget);
      final convId = (await storage.getConversations()).single.id;

      await tester.tap(find.byTooltip(l10n.askStop));
      await tester.pump();
      round1Completer.complete(
        const LlmChatResponse(content: 'Should not appear'),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.askStop), findsNothing);
      expect(find.text(l10n.askErrorFailed), findsNothing);
      expect(find.text('Should not appear'), findsNothing);
      expect(await storage.getConversations(), isEmpty);
      expect(storage.messagesFor(convId), isEmpty);
      final composer = tester.widget<TextField>(find.byType(TextField));
      expect(composer.controller!.text, 'Mix per la sera');
    },
  );

  testWidgets(
    'Stop on a follow-up keeps the conversation and restores the prompt',
    (tester) async {
      final round1Completer = Completer<LlmChatResponse>();
      final chatRepo = _CallbackChatRepo((callIdx, messages) {
        if (callIdx == 0) {
          return Future.value(
            const LlmChatResponse(
              toolCalls: [
                AskToolCall(
                  id: 'tc_1',
                  name: 'search_catalog',
                  arguments: {'query': 'M83', 'type': 'songs'},
                ),
              ],
            ),
          );
        }
        return round1Completer.future;
      });
      final storage = _FakeAskStorageRepo(
        conversations: [
          AskConversationSummary(
            id: 'conv_keep',
            title: 'Existing chat',
            createdAt: DateTime(2026, 11, 21),
            updatedAt: DateTime(2026, 11, 21),
          ),
        ],
        messagesByConv: {
          'conv_keep': [
            AskChatMessage(
              id: 'u0',
              conversationId: 'conv_keep',
              role: 'user',
              content: 'Ciao',
              createdAt: DateTime(2026, 11, 21, 10),
            ),
            AskChatMessage(
              id: 'a0',
              conversationId: 'conv_keep',
              role: 'assistant',
              content: 'Eccomi',
              createdAt: DateTime(2026, 11, 21, 10, 1),
            ),
          ],
        },
      );
      addTearDown(storage.dispose);

      final l10n = await _pumpAskScreen(
        tester,
        size: const Size(1680, 900),
        storage: storage,
        chatRepo: chatRepo,
      );

      await tester.tap(find.text('Existing chat'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ancora un mix');
      await tester.tap(find.byIcon(LucideIcons.arrowUp));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byTooltip(l10n.askStop), findsOneWidget);
      await tester.tap(find.byTooltip(l10n.askStop));
      await tester.pump();
      round1Completer.complete(
        const LlmChatResponse(content: 'Risposta scartata'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Risposta scartata'), findsNothing);
      expect(await storage.getConversations(), hasLength(1));
      expect(storage.messagesFor('conv_keep').map((m) => m.id), ['u0', 'a0']);
      final composer = tester.widget<TextField>(find.byType(TextField));
      expect(composer.controller!.text, 'Ancora un mix');
    },
  );

  testWidgets('Copy reply puts the assistant text on the clipboard', (
    tester,
  ) async {
    final clipboardCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboardCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final storage = _FakeAskStorageRepo(
      conversations: [
        AskConversationSummary(
          id: 'conv_copy',
          title: 'Copy Chat',
          createdAt: DateTime(2026, 11, 21),
          updatedAt: DateTime(2026, 11, 21),
        ),
      ],
      messagesByConv: {
        'conv_copy': [
          AskChatMessage(
            id: 'm1',
            conversationId: 'conv_copy',
            role: 'assistant',
            content: 'Ascolta questo mix',
            createdAt: DateTime(2026, 11, 21),
          ),
        ],
      },
    );
    addTearDown(storage.dispose);

    final l10n = await _pumpAskScreen(
      tester,
      size: const Size(1680, 900),
      storage: storage,
    );
    await tester.tap(find.text('Copy Chat'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l10n.askCopyReply));
    await tester.pumpAndSettle();

    expect(clipboardCalls, hasLength(1));
    expect(
      (clipboardCalls.single.arguments as Map)['text'],
      'Ascolta questo mix',
    );
    expect(find.text(l10n.askCopied), findsOneWidget);
    FeedbackToast.dismiss();
    await tester.pump();
  });

  testWidgets('Regenerate replaces the last assistant reply', (tester) async {
    final chatRepo = _CallbackChatRepo(
      (_, _) async => const LlmChatResponse(content: 'Risposta nuova'),
    );
    final storage = _FakeAskStorageRepo(
      conversations: [
        AskConversationSummary(
          id: 'conv_regen',
          title: 'Regen Chat',
          createdAt: DateTime(2026, 11, 21),
          updatedAt: DateTime(2026, 11, 21),
        ),
      ],
      messagesByConv: {
        'conv_regen': [
          AskChatMessage(
            id: 'u1',
            conversationId: 'conv_regen',
            role: 'user',
            content: 'Rigenera questa risposta',
            createdAt: DateTime(2026, 11, 21, 10),
          ),
          AskChatMessage(
            id: 'a1',
            conversationId: 'conv_regen',
            role: 'assistant',
            content: 'Risposta vecchia',
            createdAt: DateTime(2026, 11, 21, 10, 1),
          ),
        ],
      },
    );
    addTearDown(storage.dispose);

    final l10n = await _pumpAskScreen(
      tester,
      size: const Size(1680, 900),
      storage: storage,
      chatRepo: chatRepo,
    );
    await tester.tap(find.text('Regen Chat'));
    await tester.pumpAndSettle();
    expect(find.text('Risposta vecchia'), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.askRegenerate));
    await tester.pumpAndSettle();

    expect(find.text('Risposta nuova'), findsOneWidget);
    expect(find.text('Risposta vecchia'), findsNothing);
    final messages = storage.messagesFor('conv_regen');
    expect(messages.where((m) => m.isUser), hasLength(1));
    expect(messages.where((m) => !m.isUser), hasLength(1));
  });

  testWidgets(
    'Escape stops an in-flight turn and restores the prompt in the composer',
    (tester) async {
      final round1Completer = Completer<LlmChatResponse>();
      final chatRepo = _CallbackChatRepo((callIdx, messages) {
        if (callIdx == 0) {
          return Future.value(
            const LlmChatResponse(
              toolCalls: [
                AskToolCall(
                  id: 'tc_1',
                  name: 'search_catalog',
                  arguments: {'query': 'M83', 'type': 'songs'},
                ),
              ],
            ),
          );
        }
        return round1Completer.future;
      });
      final storage = _FakeAskStorageRepo();
      addTearDown(storage.dispose);

      final l10n = await _pumpAskScreen(
        tester,
        size: const Size(400, 800),
        storage: storage,
        chatRepo: chatRepo,
      );

      await tester.enterText(find.byType(TextField), 'Mix notturno');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byTooltip(l10n.askStop), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      round1Completer.complete(
        const LlmChatResponse(content: 'Risposta scartata'),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.askStop), findsNothing);
      expect(find.text('Risposta scartata'), findsNothing);
      final composer = tester.widget<TextField>(find.byType(TextField));
      expect(composer.controller!.text, 'Mix notturno');
    },
  );

  testWidgets('Conversation keeps a centered reading column on wide layouts', (
    tester,
  ) async {
    final storage = _FakeAskStorageRepo(
      conversations: [
        AskConversationSummary(
          id: 'conv_layout',
          title: 'Layout Chat',
          createdAt: DateTime(2026, 11, 21),
          updatedAt: DateTime(2026, 11, 21),
        ),
      ],
      messagesByConv: {
        'conv_layout': [
          AskChatMessage(
            id: 'm_layout',
            conversationId: 'conv_layout',
            role: 'assistant',
            content: 'Risposta in colonna',
            createdAt: DateTime(2026, 11, 21),
          ),
        ],
      },
    );
    addTearDown(storage.dispose);

    await _pumpAskScreen(tester, size: const Size(1680, 900), storage: storage);
    await tester.tap(find.text('Layout Chat'));
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(
      find.byKey(const ValueKey('askConversationList')),
    );
    final padding = list.padding! as EdgeInsets;
    expect(padding.left, greaterThan(16));
    expect(padding.right, padding.left);
    final assistant = tester.getRect(
      find.byKey(const ValueKey('askAssistantMessage')),
    );
    expect(assistant.width, lessThanOrEqualTo(760));
  });

  testWidgets(
    'compact mobile shell keeps the Ask composer above the mini player',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = _FakeAskStorageRepo();
      addTearDown(storage.dispose);

      final router = GoRouter(
        initialLocation: '/ask',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => MobileShell(navigationShell: shell),
            branches: [
              for (final path in const [
                '/',
                '/search',
                '/library',
                '/downloads',
                '/ask',
              ])
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: path,
                      builder: (_, _) => path == '/ask'
                          ? const AskScreen()
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            isOfflineProvider.overrideWithValue(false),
            isAndroidTvProvider.overrideWithValue(false),
            askCapabilitiesProvider.overrideWith(
              (_) async => AskCapabilities(
                backend: AskBackendMode.proxy,
                isOffline: false,
              ),
            ),
            askStorageRepositoryProvider.overrideWithValue(storage),
            libraryRepositoryProvider.overrideWithValue(_FakeLibraryRepo()),
            musicRepositoryProvider.overrideWithValue(_FakeWidgetMusicRepo()),
            playerStateProvider.overrideWith(_FakePlayingPlayer.new),
            askChatRepositoryProvider.overrideWithValue(
              _CallbackChatRepo(
                (_, _) async => const LlmChatResponse(content: 'Ok'),
              ),
            ),
            downloadedIdsProvider.overrideWithValue(const {}),
            askUnreadDropsCountProvider.overrideWithValue(0),
            dockBannersVisibleProvider.overrideWithValue(false),
          ],
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final composer = tester.getRect(find.byType(AskComposer));
      final miniPlayer = tester.getRect(find.byType(PlayerSheetMobile));
      expect(miniPlayer.height, 60);
      expect(composer.overlaps(miniPlayer), isFalse);
      expect(composer.bottom, lessThanOrEqualTo(miniPlayer.top));
    },
  );

  testWidgets(
    'Retry button on failure retries without duplicating persisted user message',
    (tester) async {
      final chatRepo = _CallbackChatRepo((callIdx, messages) async {
        if (callIdx == 0) {
          throw StateError('Temporary failure');
        }
        return const LlmChatResponse(content: 'Ecco la risposta recuperata!');
      });
      final storage = _FakeAskStorageRepo();
      addTearDown(storage.dispose);

      final l10n = await _pumpAskScreen(
        tester,
        size: const Size(400, 800),
        storage: storage,
        chatRepo: chatRepo,
      );

      await tester.enterText(find.byType(TextField), 'Consigliami brani chill');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text(l10n.askErrorFailed), findsOneWidget);
      expect(find.text(l10n.askActionRetry), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text(l10n.askErrorFailed),
          matching: find.byType(AskScreen),
        ),
        findsNothing,
      );
      final convId = (await storage.getConversations()).single.id;
      expect(storage.messagesFor(convId).where((m) => m.isUser), hasLength(1));

      await tester.tap(find.text(l10n.askActionRetry));
      await tester.pumpAndSettle();

      expect(find.text(l10n.askActionRetry), findsNothing);
      expect(find.text('Ecco la risposta recuperata!'), findsOneWidget);
      final msgs = storage.messagesFor(convId);
      expect(msgs.where((m) => m.isUser), hasLength(1));
      expect(msgs.where((m) => !m.isUser), hasLength(1));
    },
  );

  testWidgets(
    'dismissing sticky FeedbackToast error via close icon clears Ask error state',
    (tester) async {
      final chatRepo = _CallbackChatRepo(
        (_, _) async => throw StateError('Failure'),
      );
      final storage = _FakeAskStorageRepo();
      addTearDown(storage.dispose);

      final l10n = await _pumpAskScreen(
        tester,
        size: const Size(400, 800),
        storage: storage,
        chatRepo: chatRepo,
      );

      await tester.enterText(find.byType(TextField), 'Prova errore');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(FeedbackToast.isStickyVisible, isTrue);
      expect(find.text(l10n.askErrorFailed), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.close));
      await tester.pumpAndSettle();

      expect(FeedbackToast.isStickyVisible, isFalse);
      expect(find.text(l10n.askErrorFailed), findsNothing);
    },
  );

  testWidgets(
    'parametric guided sheets open in centered Dialog on wide layout and Expand Playlist sends playlist id and target',
    (tester) async {
      final library = _FakeLibraryRepo()
        ..playlists.add(
          LocalPlaylistModel(
            id: 7,
            name: 'R&B Notturno',
            createdAt: DateTime(2026, 11, 21),
          ),
        );
      final sentPrompts = <String>[];
      final chatRepo = _CallbackChatRepo((callIdx, messages) async {
        sentPrompts.add(messages.last.content ?? '');
        return const LlmChatResponse(content: 'Ok!');
      });

      final wideStorage = _FakeAskStorageRepo();
      addTearDown(wideStorage.dispose);
      final l10n = await _pumpAskScreen(
        tester,
        size: const Size(1680, 900),
        storage: wideStorage,
        library: library,
        chatRepo: chatRepo,
      );

      await tester.tap(find.text(l10n.askGuidedMixTitle).first);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);

      await tester.tap(find.text(l10n.askGuidedExpandPlaylistTitle).first);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('R&B Notturno'), findsOneWidget);

      await tester.tap(find.text(l10n.askExpandTargetReach50));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.askExpandSubmit));
      await tester.pumpAndSettle();

      expect(sentPrompts.single, contains('R&B Notturno'));
      expect(sentPrompts.single, contains('7'));
      expect(sentPrompts.single, contains('50'));
    },
  );

  testWidgets(
    'parametric Tailored Mix sheet opens as BottomSheet on compact layout and submits vibe and length',
    (tester) async {
      final sentPrompts = <String>[];
      final chatRepo = _CallbackChatRepo((callIdx, messages) async {
        sentPrompts.add(messages.last.content ?? '');
        return const LlmChatResponse(content: 'Ok!');
      });

      final compactStorage = _FakeAskStorageRepo();
      addTearDown(compactStorage.dispose);
      final l10n = await _pumpAskScreen(
        tester,
        size: const Size(400, 800),
        storage: compactStorage,
        chatRepo: chatRepo,
      );

      await tester.tap(find.text(l10n.askGuidedMixTitle));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);

      await tester.tap(find.text(l10n.askMixVibeFocus));
      await tester.tap(find.text(l10n.askTracksCount(30)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.askMixSubmit));
      await tester.pumpAndSettle();

      expect(sentPrompts.single, contains('30'));
      expect(sentPrompts.single, contains(l10n.askMixVibeFocus));
    },
  );

  testWidgets('syncs server quota on AskScreen init in proxy mode', (
    tester,
  ) async {
    final chatRepo = _CallbackChatRepo(
      (_, _) async => const LlmChatResponse(content: 'Ok'),
      quota: const AskQuotaInfo(remaining: 19, limit: 30),
    );
    final l10n = await _pumpAskScreen(
      tester,
      size: const Size(400, 800),
      chatRepo: chatRepo,
    );

    expect(find.text(l10n.askQuotaBadge(19, 30)), findsOneWidget);
  });

  testWidgets('clear history shows confirmation dialog before wiping chats', (
    tester,
  ) async {
    final storage = _FakeAskStorageRepo(
      conversations: [
        AskConversationSummary(
          id: 'c_old',
          title: 'Dream Pop Mix',
          createdAt: DateTime(2026, 11, 21),
          updatedAt: DateTime(2026, 11, 21),
        ),
      ],
      messagesByConv: {
        'c_old': [
          AskChatMessage(
            id: 'm1',
            conversationId: 'c_old',
            role: 'user',
            content: 'Dream pop pls',
            createdAt: DateTime(2026, 11, 21),
          ),
        ],
      },
    );
    addTearDown(storage.dispose);

    final l10n = await _pumpAskScreen(
      tester,
      size: const Size(1680, 900),
      storage: storage,
    );

    expect(find.text('Dream Pop Mix'), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.askClearHistory));
    await tester.pumpAndSettle();
    expect(find.text(l10n.askClearHistoryConfirmTitle), findsOneWidget);

    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(await storage.getConversations(), hasLength(1));

    await tester.tap(find.byTooltip(l10n.askClearHistory));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.askClearHistory),
      ),
    );
    await tester.pumpAndSettle();

    expect(await storage.getConversations(), isEmpty);
    expect(find.text(l10n.askHistoryEmpty), findsOneWidget);
  });

  testWidgets(
    'navigating to /ask?prompt=... starts a fresh conversation instead of appending to active chat',
    (tester) async {
      tester.view.physicalSize = const Size(1680, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = _FakeAskStorageRepo(
        conversations: [
          AskConversationSummary(
            id: 'c_prev',
            title: 'Old Ambient Chat',
            createdAt: DateTime(2026, 11, 21),
            updatedAt: DateTime(2026, 11, 21),
          ),
        ],
        messagesByConv: {
          'c_prev': [
            AskChatMessage(
              id: 'm_prev',
              conversationId: 'c_prev',
              role: 'assistant',
              content: 'Existing ambient response',
              createdAt: DateTime(2026, 11, 21),
            ),
          ],
        },
      );
      addTearDown(storage.dispose);
      final chatRepo = _CallbackChatRepo(
        (_, _) async =>
            const LlmChatResponse(content: 'Fresh synthwave answer'),
      );

      final router = GoRouter(
        initialLocation: '/ask',
        routes: [
          GoRoute(
            path: '/ask',
            builder: (context, state) => AskScreen(
              initialPrompt: state.uri.queryParameters['prompt'],
              initialDropId: state.uri.queryParameters['dropId'],
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            isOfflineProvider.overrideWithValue(false),
            isAndroidTvProvider.overrideWithValue(false),
            askCapabilitiesProvider.overrideWith(
              (_) async => const AskCapabilities(
                backend: AskBackendMode.proxy,
                isOffline: false,
              ),
            ),
            askStorageRepositoryProvider.overrideWithValue(storage),
            libraryRepositoryProvider.overrideWithValue(_FakeLibraryRepo()),
            musicRepositoryProvider.overrideWithValue(_FakeWidgetMusicRepo()),
            playerStateProvider.overrideWith(_FakePlayer.new),
            askChatRepositoryProvider.overrideWithValue(chatRepo),
            downloadedIdsProvider.overrideWithValue(const {}),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Old Ambient Chat'));
      await tester.pumpAndSettle();
      expect(find.text('Existing ambient response'), findsOneWidget);

      router.go(
        Uri(
          path: '/ask',
          queryParameters: {'prompt': 'Play dreamy synthwave'},
        ).toString(),
      );
      await tester.pumpAndSettle();

      final convs = await storage.getConversations();
      expect(convs, hasLength(2));
      expect(storage.messagesFor('c_prev'), hasLength(1));
      expect(find.text('Fresh synthwave answer'), findsOneWidget);
      expect(find.text('Existing ambient response'), findsNothing);
    },
  );

  testWidgets(
    'allows removing individual tracks from unsaved AskMixCard and pending AskPlaylistProposalCard only',
    (tester) async {
      const tracks = [
        AskTrackRef(videoId: 'v1', title: 'Track Alpha', artist: 'Artist A'),
        AskTrackRef(videoId: 'v2', title: 'Track Beta', artist: 'Artist B'),
      ];
      final storage = _FakeAskStorageRepo(
        conversations: [
          AskConversationSummary(
            id: 'c_edit',
            title: 'Editable Cards',
            createdAt: DateTime(2026, 11, 21),
            updatedAt: DateTime(2026, 11, 21),
          ),
        ],
        messagesByConv: {
          'c_edit': [
            AskChatMessage(
              id: 'm_cards',
              conversationId: 'c_edit',
              role: 'assistant',
              content: 'Here you go',
              attachments: const [
                AskMixAttachment(title: 'Editable Mix', tracks: tracks),
                AskPlaylistWriteProposal(
                  operation: 'create',
                  playlistName: 'Pending Proposal',
                  tracks: tracks,
                ),
                AskPlaylistWriteProposal(
                  operation: 'create',
                  playlistName: 'Saved Proposal',
                  tracks: tracks,
                  status: 'saved',
                  savedPlaylistId: 9,
                ),
              ],
              createdAt: DateTime(2026, 11, 21),
            ),
          ],
        },
      );
      addTearDown(storage.dispose);

      final l10n = await _pumpAskScreen(
        tester,
        size: const Size(1680, 2600),
        storage: storage,
      );

      await tester.tap(find.text('Editable Cards'));
      await tester.pumpAndSettle();

      // 2 editable cards (unsaved mix + pending proposal) * 2 tracks = 4 buttons;
      // the saved proposal card has zero remove buttons.
      expect(find.byTooltip(l10n.askRemoveTrackFromCard), findsNWidgets(4));

      await tester.tap(find.byTooltip(l10n.askRemoveTrackFromCard).first);
      await tester.pumpAndSettle();

      // Removing 1 track from Editable Mix drops its count to 1 -> hides remaining
      // remove icon on Editable Mix; 2 remain on Pending Proposal.
      expect(find.byTooltip(l10n.askRemoveTrackFromCard), findsNWidgets(2));
      final updatedMsg = storage.messagesFor('c_edit').single;
      final mix = updatedMsg.attachments[0] as AskMixAttachment;
      expect(mix.tracks.map((t) => t.videoId), ['v2']);
      expect(find.text(l10n.askTracksCount(1)), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.askRemoveTrackFromCard).last);
      await tester.pumpAndSettle();

      final finalMsg = storage.messagesFor('c_edit').single;
      final proposal = finalMsg.attachments[1] as AskPlaylistWriteProposal;
      expect(proposal.tracks.map((t) => t.videoId), ['v1']);
      expect(find.byTooltip(l10n.askRemoveTrackFromCard), findsNothing);
    },
  );

  group('contextual Ask context menu entries', () {
    Future<void> pumpContextMenu({
      required WidgetTester tester,
      required Widget sheet,
      required bool offline,
      required bool isTv,
      List<String>? navigatedUris,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Column(
                children: [
                  Expanded(child: sheet),
                  ElevatedButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      builder: (_) => sheet,
                    ),
                    child: const Text('open_modal'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/ask',
            builder: (_, state) {
              navigatedUris?.add(state.uri.toString());
              return Scaffold(
                body: Text('ASK:${state.uri.queryParameters['prompt']}'),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            isOfflineProvider.overrideWithValue(offline),
            isAndroidTvProvider.overrideWithValue(isTv),
            libraryRepositoryProvider.overrideWithValue(_FakeLibraryRepo()),
            musicRepositoryProvider.overrideWithValue(_FakeWidgetMusicRepo()),
            playerStateProvider.overrideWith(_FakePlayer.new),
            downloadedIdsProvider.overrideWithValue(const {}),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'Song, Artist, and CustomPlaylist context menus show Ask actions online, disable offline, and hide on TV',
      (tester) async {
        final playlist = LocalPlaylistModel(
          id: 42,
          name: 'Night Drive',
          createdAt: DateTime(2026, 11, 21),
        );
        const songSheet = SongContextMenuSheet(
          videoId: 'vid_m83',
          title: 'Midnight City',
          artist: 'M83',
          artistId: 'UC_M83',
          albumId: 'MPRE_1',
        );
        const artistSheet = ArtistContextMenuSheet(
          artistId: 'UC_M83',
          name: 'M83',
        );
        final playlistSheet = CustomPlaylistContextMenuSheet(
          playlist: playlist,
          onUpdated: () {},
        );

        // Online non-TV: song menu navigates with prompt & pops modal.
        final navUris = <String>[];
        await pumpContextMenu(
          tester: tester,
          sheet: songSheet,
          offline: false,
          isTv: false,
          navigatedUris: navUris,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(SongContextMenuSheet)),
        )!;
        expect(find.text(l10n.askContextSimilarSongs), findsOneWidget);
        await tester.tap(find.text('open_modal'));
        await tester.pumpAndSettle();
        final modalAskTile = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(l10n.askContextSimilarSongs),
        );
        await tester.ensureVisible(modalAskTile);
        await tester.tap(modalAskTile);
        await tester.pumpAndSettle();
        expect(navUris.single, startsWith('/ask?prompt='));
        expect(find.textContaining('Midnight City'), findsOneWidget);

        // Online non-TV: artist menu & custom playlist menu navigate with prompt.
        final artistUris = <String>[];
        await pumpContextMenu(
          tester: tester,
          sheet: artistSheet,
          offline: false,
          isTv: false,
          navigatedUris: artistUris,
        );
        await tester.ensureVisible(find.text(l10n.askContextSimilarArtists));
        await tester.tap(find.text(l10n.askContextSimilarArtists));
        await tester.pumpAndSettle();
        expect(artistUris.single, startsWith('/ask?prompt='));
        expect(find.textContaining('M83'), findsOneWidget);

        final plUris = <String>[];
        await pumpContextMenu(
          tester: tester,
          sheet: playlistSheet,
          offline: false,
          isTv: false,
          navigatedUris: plUris,
        );
        await tester.ensureVisible(find.text(l10n.askContextExpandPlaylist));
        await tester.tap(find.text(l10n.askContextExpandPlaylist));
        await tester.pumpAndSettle();
        expect(plUris.single, startsWith('/ask?prompt='));
        expect(find.textContaining('Night Drive'), findsOneWidget);

        // Offline: actions visible but disabled.
        await pumpContextMenu(
          tester: tester,
          sheet: songSheet,
          offline: true,
          isTv: false,
        );
        final songTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text(l10n.askContextSimilarSongs),
            matching: find.byType(ListTile),
          ),
        );
        expect(songTile.enabled, isFalse);

        await pumpContextMenu(
          tester: tester,
          sheet: artistSheet,
          offline: true,
          isTv: false,
        );
        final artistTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text(l10n.askContextSimilarArtists),
            matching: find.byType(ListTile),
          ),
        );
        expect(artistTile.enabled, isFalse);

        await pumpContextMenu(
          tester: tester,
          sheet: playlistSheet,
          offline: true,
          isTv: false,
        );
        final plTile = tester.widget<ListTile>(
          find.ancestor(
            of: find.text(l10n.askContextExpandPlaylist),
            matching: find.byType(ListTile),
          ),
        );
        expect(plTile.enabled, isFalse);

        // Android TV: Ask entries completely hidden.
        await pumpContextMenu(
          tester: tester,
          sheet: songSheet,
          offline: false,
          isTv: true,
        );
        expect(find.text(l10n.askContextSimilarSongs), findsNothing);

        await pumpContextMenu(
          tester: tester,
          sheet: artistSheet,
          offline: false,
          isTv: true,
        );
        expect(find.text(l10n.askContextSimilarArtists), findsNothing);

        await pumpContextMenu(
          tester: tester,
          sheet: playlistSheet,
          offline: false,
          isTv: true,
        );
        expect(find.text(l10n.askContextExpandPlaylist), findsNothing);
      },
    );
  });
}

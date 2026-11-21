import 'dart:async';

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
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/ask/ask_screen.dart';
import 'package:sonora/presentation/features/ask/widgets/ask_composer.dart';
import 'package:sonora/presentation/features/ask/widgets/ask_drops_section.dart';
import 'package:sonora/presentation/features/ask/widgets/ask_guided_actions.dart';
import 'package:sonora/presentation/features/tv/layouts/tv_shell.dart';
import 'package:sonora/presentation/features/tv/tv_metrics.dart';
import 'package:sonora/presentation/providers/android_tv_provider.dart';
import 'package:sonora/presentation/providers/ask_llm_provider.dart';
import 'package:sonora/presentation/providers/ask_storage_provider.dart';
import 'package:sonora/presentation/providers/connectivity_provider.dart';
import 'package:sonora/presentation/providers/download_provider.dart';
import 'package:sonora/presentation/providers/library_repository_provider.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';

class _FakePlayer extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
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

Future<AppLocalizations> _pumpAskScreen(
  WidgetTester tester, {
  required Size size,
  bool offline = false,
  _FakeAskStorageRepo? storage,
  _FakeLibraryRepo? library,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fakeStorage = storage ?? _FakeAskStorageRepo();
  if (storage == null) addTearDown(fakeStorage.dispose);
  final fakeLib = library ?? _FakeLibraryRepo();

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
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AskScreen(),
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
}

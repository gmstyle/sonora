import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/core/theme/brand_accent.dart';
import 'package:sonora/core/theme/player_colors.dart';
import 'package:sonora/domain/models/ask_capabilities.dart';
import 'package:sonora/domain/models/ask_mode.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/player/widgets/lyrics_view.dart';
import 'package:sonora/presentation/features/tv/layouts/tv_shell.dart';
import 'package:sonora/presentation/features/tv/screens/tv_now_playing_screen.dart';
import 'package:sonora/presentation/features/tv/tv_metrics.dart';
import 'package:sonora/presentation/features/tv/widgets/tv_category_card.dart';
import 'package:sonora/presentation/features/tv/widgets/tv_featured_card.dart';
import 'package:sonora/presentation/features/tv/widgets/tv_focusable.dart';
import 'package:sonora/presentation/features/tv/widgets/tv_now_playing_pill.dart';
import 'package:sonora/presentation/features/tv/widgets/tv_poster_card.dart';
import 'package:sonora/presentation/features/tv/widgets/tv_shelf.dart';
import 'package:sonora/presentation/providers/android_tv_provider.dart';
import 'package:sonora/presentation/providers/connectivity_provider.dart';
import 'package:sonora/presentation/providers/download_provider.dart';
import 'package:sonora/presentation/providers/library_notifier.dart';
import 'package:sonora/presentation/providers/on_device_llm_provider.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';
import 'package:sonora/presentation/shared/widgets/context_menu/action_tiles.dart';
import 'package:sonora/presentation/shared/widgets/context_menu_sheet.dart';
import 'package:sonora/presentation/shared/widgets/sonora_logo.dart';

class _FakePlayer extends PlayerNotifier {
  final PlayerState initial;
  int toggleCalls = 0;
  int nextCalls = 0;
  int prevCalls = 0;

  _FakePlayer(this.initial);

  @override
  PlayerState build() => initial;

  @override
  Future<void> togglePlayPause() async {
    toggleCalls++;
  }

  @override
  Future<void> skipToNext() async {
    nextCalls++;
  }

  @override
  Future<void> skipToPrevious() async {
    prevCalls++;
  }
}

void main() {
  final playingState = PlayerState(
    currentSong: const MediaItem(
      id: 'song-1',
      title: 'Test Track',
      artist: 'Test Artist',
    ),
    isPlaying: true,
    duration: const Duration(minutes: 3),
  );

  Future<void> pumpTvShell(
    WidgetTester tester, {
    required List<Widget> homeChildren,
    PlayerState playerState = const PlayerState(),
    List<Widget>? branch1Children,
  }) async {
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
          builder: (context, state, navigationShell) =>
              TvShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => ListView(children: homeChildren),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/search',
                  builder: (context, state) => ListView(
                    children:
                        branch1Children ??
                        [
                          TvFocusable(
                            key: const Key('branch1-item'),
                            onSelect: () {},
                            child: const SizedBox(
                              width: 120,
                              height: 48,
                              child: Text('Search Input'),
                            ),
                          ),
                        ],
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/library',
                  builder: (context, state) => const SizedBox.shrink(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/downloads',
                  builder: (context, state) => const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    SharedPreferences.setMockInitialValues({kReduceEffectsKey: true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playerStateProvider.overrideWith(() => _FakePlayer(playerState)),
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
  }

  bool isFocused(WidgetTester tester, Key key) {
    final target = find.byKey(key);
    expect(target, findsOneWidget);
    final focusElements = find
        .descendant(of: target, matching: find.byType(Focus))
        .evaluate();
    for (final element in focusElements) {
      final focus = element.widget as Focus;
      if (focus.focusNode?.hasFocus == true) return true;
      final child = find.descendant(
        of: find.byWidget(focus),
        matching: find.byType(GestureDetector),
      );
      if (child.evaluate().isNotEmpty &&
          Focus.of(child.evaluate().first).hasFocus) {
        return true;
      }
    }
    return false;
  }

  double sidebarWidth(WidgetTester tester) {
    final rail = find.ancestor(
      of: find.byType(SonoraLogo),
      matching: find.byType(AnimatedContainer),
    );
    return tester.getSize(rail.first).width;
  }

  testWidgets('starts with sidebar collapsed and focus on first content item', (
    tester,
  ) async {
    await pumpTvShell(
      tester,
      homeChildren: [
        TvShelf(
          title: 'Row 1',
          children: [
            TvPosterCard(
              key: const Key('r1-c0'),
              title: 'Card 0',
              autofocus: true,
              onSelect: () {},
            ),
            TvPosterCard(
              key: const Key('r1-c1'),
              title: 'Card 1',
              onSelect: () {},
            ),
          ],
        ),
      ],
    );

    expect(isFocused(tester, const Key('r1-c0')), isTrue);
    expect(sidebarWidth(tester), TvMetrics.railCollapsedWidth);
  });

  testWidgets(
    'left on first shelf item opens sidebar and right/escape returns to content',
    (tester) async {
      await pumpTvShell(
        tester,
        homeChildren: [
          TvShelf(
            title: 'Row 1',
            children: [
              // Intentionally omit onLeftAtEdge to verify TvShelf._ShelfLeadingFocus.
              TvPosterCard(
                key: const Key('r1-c0'),
                title: 'Card 0',
                autofocus: true,
                onSelect: () {},
              ),
              TvPosterCard(
                key: const Key('r1-c1'),
                title: 'Card 1',
                onSelect: () {},
              ),
            ],
          ),
        ],
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(isFocused(tester, const Key('r1-c1')), isTrue);

      // Left from card 1 stays in shelf on card 0.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(isFocused(tester, const Key('r1-c0')), isTrue);

      // Left from card 0 opens the sidebar overlay.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(isFocused(tester, const Key('r1-c0')), isFalse);
      expect(sidebarWidth(tester), TvMetrics.railExpandedWidth);

      // Escape collapses sidebar and returns focus to content.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(sidebarWidth(tester), TvMetrics.railCollapsedWidth);
      expect(isFocused(tester, const Key('r1-c0')), isTrue);
    },
  );

  testWidgets(
    'arrowDown scrolls through all shelves without dock jump and arrowUp at top reaches TvNowPlayingPill',
    (tester) async {
      await pumpTvShell(
        tester,
        playerState: playingState,
        homeChildren: [
          for (var r = 0; r < 5; r++)
            TvShelf(
              title: 'Row $r',
              children: [
                TvPosterCard(
                  key: Key('r$r-c0'),
                  title: 'Item $r.0',
                  autofocus: r == 0,
                  onSelect: () {},
                ),
              ],
            ),
        ],
      );

      expect(isFocused(tester, const Key('r0-c0')), isTrue);

      // Pressing Up at the very top row moves focus to TvNowPlayingPill.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(find.textContaining('Test Track'), findsWidgets);
      final pillFocus = FocusManager.instance.primaryFocus;
      expect(pillFocus, isNotNull);
      expect(
        pillFocus!.context?.findAncestorWidgetOfExactType<TvNowPlayingPill>() !=
                null ||
            find
                .ancestor(
                  of: find.byWidget(pillFocus.context!.widget),
                  matching: find.byType(TvNowPlayingPill),
                )
                .evaluate()
                .isNotEmpty,
        isTrue,
        reason: 'Focus should move into TvNowPlayingPill on Up at top',
      );

      // Pressing Down from TvNowPlayingPill returns focus to row 0.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused(tester, const Key('r0-c0')), isTrue);

      // Walk down all 5 shelves; focus stays on the last row at the bottom.
      for (var r = 1; r < 5; r++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        // If focus was scrolled before reaching the item, press once more if needed.
        if (!isFocused(tester, Key('r$r-c0'))) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
        }
        expect(
          isFocused(tester, Key('r$r-c0')),
          isTrue,
          reason: 'Expected focus on Row $r',
        );
      }

      // At the bottom row, pressing Down again keeps focus on row 4 (no bottom dock).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused(tester, const Key('r4-c0')), isTrue);
    },
  );

  testWidgets(
    'selecting a sidebar destination collapses rail and moves focus to branch content',
    (tester) async {
      await pumpTvShell(
        tester,
        homeChildren: [
          TvShelf(
            title: 'Row 1',
            children: [
              TvPosterCard(
                key: const Key('r1-c0'),
                title: 'Card 0',
                autofocus: true,
                onSelect: () {},
              ),
            ],
          ),
        ],
      );

      // Open sidebar
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      // Move down to Search (index 1) and press Enter
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(isFocused(tester, const Key('branch1-item')), isTrue);
    },
  );

  testWidgets(
    'top-positioned item above empty body does not jump abruptly to dock on arrowDown',
    (tester) async {
      await pumpTvShell(
        tester,
        playerState: playingState,
        homeChildren: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: TvFocusable(
              key: const Key('top-chip'),
              autofocus: true,
              onSelect: () {},
              child: const SizedBox(
                width: 120,
                height: 40,
                child: Text('Top Chip'),
              ),
            ),
          ),
        ],
      );

      expect(isFocused(tester, const Key('top-chip')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Focus stays on the top chip instead of teleporting across empty space to dock.
      expect(isFocused(tester, const Key('top-chip')), isTrue);
    },
  );

  testWidgets('arrowLeft on TvNowPlayingPill opens sidebar', (tester) async {
    await pumpTvShell(
      tester,
      playerState: playingState,
      homeChildren: [
        TvShelf(
          title: 'Row 0',
          children: [
            TvPosterCard(
              key: const Key('r0-c0'),
              title: 'Item 0',
              autofocus: true,
              onSelect: () {},
            ),
          ],
        ),
      ],
    );

    // Move up from top row to TvNowPlayingPill, then left to open sidebar.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(isFocused(tester, const Key('r0-c0')), isFalse);
    expect(sidebarWidth(tester), TvMetrics.railCollapsedWidth);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(sidebarWidth(tester), TvMetrics.railExpandedWidth);
  });

  testWidgets(
    'TvNowPlayingScreen focuses Play/Pause and reaches transport, lyrics, and queue with D-pad',
    (tester) async {
      tester.view.physicalSize = const Size(
        TvMetrics.designWidth,
        TvMetrics.designHeight,
      );
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakePlayer = _FakePlayer(
        PlayerState(
          currentSong: const MediaItem(
            id: 'vid-np',
            title: 'Houdini',
            artist: 'Dua Lipa',
            album: 'Radical Optimism',
          ),
          queue: const [
            MediaItem(id: 'vid-np', title: 'Houdini', artist: 'Dua Lipa'),
            MediaItem(id: 'vid-2', title: 'Get Lucky', artist: 'Daft Punk'),
          ],
          isPlaying: true,
          duration: const Duration(minutes: 3, seconds: 5),
          position: const Duration(minutes: 1, seconds: 28),
        ),
      );

      SharedPreferences.setMockInitialValues({kReduceEffectsKey: true});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            isAndroidTvProvider.overrideWithValue(true),
            playerStateProvider.overrideWith(() => fakePlayer),
            likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
            isOfflineProvider.overrideWithValue(false),
            lyricsProvider.overrideWith((ref, id) async => null),
            plainLyricsProvider.overrideWith(
              (ref, id) async => 'Line 1\nLine 2',
            ),
            askCapabilitiesProvider.overrideWith(
              (ref) async => const AskCapabilities(AskLlmBackend.none),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: TvTheme.apply(
              ThemeData.dark().copyWith(
                extensions: [PlayerColors.forAccent(BrandAccent.cyan)],
              ),
            ),
            home: const TvNowPlayingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Play/Pause has initial focus (debugLabel: tvNpArtPlay) and responds to Enter.
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'tvNpArtPlay');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(fakePlayer.toggleCalls, 1);

      // Right reaches skipForward and triggers skipToNext on Enter.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(fakePlayer.nextCalls, 1);

      // Left twice reaches skipBack and triggers skipToPrevious on Enter.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(fakePlayer.prevCalls, 1);

      // Move back right to Play/Pause, then Up to SeekBar, then Up to TopBar pills.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'tvSeekBar');

      // Down back to transport, Down again to quick-jump row (Queue is directly under Play/Pause).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Queue drawer opened and took focus. Escape closes it and restores Play/Pause focus.
      expect(find.text('Get Lucky'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'tvNpArtPlay');

      // Down to quick-jump row, Left to Lyrics button, Enter switches to Lyrics stage.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // In Lyrics mode, focus lands cleanly on Lyrics Play/Pause button.
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'tvNpLyricsPlay');

      // Escape returns to Artwork stage and restores Play/Pause focus.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'tvNpArtPlay');
    },
  );

  testWidgets('canvas home cards render cleanly without overflow at 960x540', (
    tester,
  ) async {
    await pumpTvShell(
      tester,
      playerState: playingState,
      homeChildren: [
        TvShelf(
          title: 'Continue Listening',
          children: [
            TvFeaturedCard(
              title: 'Radical Optimism',
              subtitle: 'Dua Lipa',
              badge: 'Album',
              autofocus: true,
              onSelect: () {},
            ),
          ],
        ),
        TvShelf(
          title: 'Moods & genres',
          children: [
            TvCategoryCard(
              title: 'Relax & Chill',
              selected: true,
              onSelect: () {},
            ),
          ],
        ),
      ],
    );

    expect(find.text('Radical Optimism'), findsOneWidget);
    expect(find.text('Relax & Chill'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TV context menu opens centered modal with focusable pills, Close button, and no Share',
    (tester) async {
      tester.view.physicalSize = const Size(
        TvMetrics.designWidth,
        TvMetrics.designHeight,
      );
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isAndroidTvProvider.overrideWithValue(true),
            isOfflineProvider.overrideWithValue(false),
            likedAlbumProvider.overrideWith((ref, id) => Stream.value(null)),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            theme: TvTheme.apply(ThemeData.dark()),
            home: Builder(
              builder: (context) => Scaffold(
                body: TvPosterCard(
                  title: 'Discovery',
                  subtitle: 'Daft Punk',
                  autofocus: true,
                  onLongSelect: () => ContextMenuSheet.showForAlbum(
                    context,
                    albumId: 'alb-1',
                    name: 'Discovery',
                    artist: 'Daft Punk',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate D-pad long-press Select (≥400ms)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      // Context menu modal is open with TvContextMenuTile rows + Close button, and Share is hidden.
      expect(find.byType(TvContextMenuTile), findsWidgets);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Share'), findsNothing);
    },
  );
}

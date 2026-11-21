import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/ask/providers/ask_chat_provider.dart';
import 'package:sonora/presentation/features/home/layouts/home_feed_layout.dart';
import 'package:sonora/presentation/features/home/layouts/home_layout_metrics.dart';
import 'package:sonora/presentation/features/home/providers/home_provider.dart';
import 'package:sonora/presentation/features/tv/layouts/tv_shell.dart';
import 'package:sonora/presentation/features/tv/tv_metrics.dart';
import 'package:sonora/presentation/features/tv/widgets/tv_poster_card.dart';
import 'package:sonora/presentation/features/tv/widgets/tv_shelf.dart';
import 'package:sonora/presentation/providers/android_tv_provider.dart';
import 'package:sonora/presentation/providers/ask_llm_provider.dart';
import 'package:sonora/presentation/providers/connectivity_provider.dart';
import 'package:sonora/presentation/providers/download_provider.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';
import 'package:sonora/presentation/providers/stats_provider.dart';
import 'package:sonora/presentation/providers/youtube_account_provider.dart';
import 'package:sonora/presentation/shared/layouts/tablet_shell.dart';
import 'package:sonora/presentation/shared/layouts/wide_shell.dart';

class _FakeYoutubeAccount extends YoutubeAccountNotifier {
  _FakeYoutubeAccount(this.initialSignedIn);

  final bool initialSignedIn;
  int signOutCalls = 0;

  @override
  YoutubeAccountState build() => YoutubeAccountState(signedIn: initialSignedIn);

  @override
  Future<void> signOut() async {
    signOutCalls++;
    state = YoutubeAccountState(
      signedIn: false,
      sessionGeneration: state.sessionGeneration + 1,
    );
  }
}

class _FakePlayer extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

class _IdleStats extends StatsNotifier {
  @override
  StatsState build() => StatsState(isLoading: false);
}

GoRouter _shellRouter(
  Widget Function(BuildContext, GoRouterState, StatefulNavigationShell) builder,
) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: builder,
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => ListView(
                  children: [
                    TvShelf(
                      title: 'Row 1',
                      children: [
                        TvPosterCard(
                          key: const Key('home-card'),
                          title: 'Item',
                          autofocus: true,
                          onSelect: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
              GoRoute(path: '/downloads', builder: (_, _) => const SizedBox()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/ask', builder: (_, _) => const SizedBox()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const Scaffold(body: Text('Settings')),
      ),
    ],
  );
}

void main() {
  final sampleAccount = AccountInfo(
    name: 'Gabriele',
    email: 'g@example.com',
    channelHandle: '@gmstyle',
  );

  Future<void> pumpHomeLayout(
    WidgetTester tester, {
    required Size view,
    required double shortestSide,
    required bool signedIn,
    AccountInfo? info,
    _FakeYoutubeAccount? accountNotifier,
  }) async {
    tester.view.physicalSize = view;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = accountNotifier ?? _FakeYoutubeAccount(signedIn);
    final home = BrowseHomeResult(chips: const [], sections: const []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isAndroidTvProvider.overrideWithValue(false),
          isOfflineProvider.overrideWithValue(false),
          youtubeAccountProvider.overrideWith(() => notifier),
          youtubeAccountInfoProvider.overrideWith((_) async => info),
          askLlmReadyProvider.overrideWith((_) async => false),
          statsProvider.overrideWith(_IdleStats.new),
          recentHistoryProvider.overrideWith((_) async => <HistoryModel>[]),
          homeRandomPlaylistsProvider.overrideWith((_) async => <dynamic>[]),
          homeRandomArtistsProvider.overrideWith(
            (_) async => <FollowedArtistModel>[],
          ),
          homeRandomAlbumsProvider.overrideWith(
            (_) async => <LikedAlbumModel>[],
          ),
          homeRandomNewReleasesProvider.overrideWith(
            (_) async => <AlbumDetailed>[],
          ),
          homeDiscoverProvider.overrideWith((_) async => <UpNextsDetails>[]),
          homeSimilarArtistsProvider.overrideWith(
            (_) async => <ArtistDetailed>[],
          ),
          homeBaseResultProvider.overrideWith((_) async => home),
          homeBaseSectionsProvider.overrideWith((_) async => const []),
          homeEditorialSectionsProvider.overrideWith((_) async => const []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeFeedLayout(
            metrics: HomeLayoutMetrics.fromWidth(
              view.width,
              shortestSide: shortestSide,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets(
    'mobile HomeFeedLayout shows Account beside Settings and opens bottom sheet when signed in',
    (tester) async {
      final accountNotifier = _FakeYoutubeAccount(true);
      await pumpHomeLayout(
        tester,
        view: const Size(390, 844),
        shortestSide: 390,
        signedIn: true,
        info: sampleAccount,
        accountNotifier: accountNotifier,
      );

      final accountFinder = find.byKey(
        const Key('youtube-account-appbar-button'),
      );
      final settingsFinder = find.byIcon(LucideIcons.settings);
      expect(accountFinder, findsOneWidget);
      expect(settingsFinder, findsOneWidget);
      expect(
        tester.getTopLeft(accountFinder).dx,
        lessThan(tester.getTopLeft(settingsFinder).dx),
      );

      await tester.tap(accountFinder);
      await tester.pumpAndSettle();

      expect(find.text('Gabriele'), findsOneWidget);
      expect(find.text('@gmstyle'), findsOneWidget);
      expect(find.text('g@example.com'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(accountNotifier.signOutCalls, 1);
      expect(find.text('@gmstyle'), findsNothing);
    },
  );

  testWidgets('tablet HomeFeedLayout removes Settings icon from AppBar', (
    tester,
  ) async {
    await pumpHomeLayout(
      tester,
      view: const Size(800, 900),
      shortestSide: 800,
      signedIn: false,
    );

    expect(
      find.byKey(const Key('youtube-account-appbar-button')),
      findsNothing,
    );
    expect(find.byIcon(LucideIcons.settings), findsNothing);
  });

  testWidgets('TabletShell shows Account above Settings in the rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = _shellRouter(
      (_, _, shell) => TabletShell(navigationShell: shell),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isAndroidTvProvider.overrideWithValue(false),
          isOfflineProvider.overrideWithValue(false),
          playerStateProvider.overrideWith(_FakePlayer.new),
          downloadBannerSummaryProvider.overrideWithValue(null),
          askUnreadDropsCountProvider.overrideWithValue(0),
          youtubeAccountProvider.overrideWith(() => _FakeYoutubeAccount(true)),
          youtubeAccountInfoProvider.overrideWith((_) async => sampleAccount),
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

    final accountBtn = find.byKey(const Key('tablet-account-button'));
    final settingsBtn = find.byIcon(LucideIcons.settings);
    expect(accountBtn, findsOneWidget);
    expect(settingsBtn, findsOneWidget);
    expect(
      tester.getTopLeft(accountBtn).dy,
      lessThan(tester.getTopLeft(settingsBtn).dy),
    );

    await tester.tap(accountBtn);
    await tester.pumpAndSettle();
    expect(find.text('Gabriele'), findsOneWidget);
    expect(find.text('@gmstyle'), findsOneWidget);
  });

  testWidgets(
    'WideShell shows Account above Settings and opens centered dialog when signed in',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = _shellRouter(
        (_, _, shell) => WideShell(navigationShell: shell),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            isAndroidTvProvider.overrideWithValue(false),
            isOfflineProvider.overrideWithValue(false),
            playerStateProvider.overrideWith(_FakePlayer.new),
            downloadBannerSummaryProvider.overrideWithValue(null),
            askUnreadDropsCountProvider.overrideWithValue(0),
            youtubeAccountProvider.overrideWith(
              () => _FakeYoutubeAccount(true),
            ),
            youtubeAccountInfoProvider.overrideWith((_) async => sampleAccount),
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

      final accountBtn = find.byKey(const Key('wide-account-button'));
      final settingsBtn = find.byIcon(LucideIcons.settings);
      expect(accountBtn, findsOneWidget);
      expect(settingsBtn, findsOneWidget);
      expect(
        tester.getTopLeft(accountBtn).dy,
        lessThan(tester.getTopLeft(settingsBtn).dy),
      );

      // Expand sidebar and verify the account name renders beside the avatar.
      await tester.tap(find.byIcon(LucideIcons.menu));
      await tester.pumpAndSettle();
      expect(find.text('Gabriele'), findsOneWidget);
      expect(
        tester.getTopLeft(accountBtn).dy,
        lessThan(tester.getTopLeft(find.text('Settings')).dy),
      );

      await tester.tap(accountBtn);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('@gmstyle'), findsOneWidget);
      expect(find.text('g@example.com'), findsOneWidget);
    },
  );

  testWidgets(
    'TvShell shows Account above Settings in sidebar and opens TV account dialog',
    (tester) async {
      tester.view.physicalSize = const Size(
        TvMetrics.designWidth,
        TvMetrics.designHeight,
      );
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final accountNotifier = _FakeYoutubeAccount(true);
      final router = _shellRouter(
        (_, _, shell) => TvShell(navigationShell: shell),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isAndroidTvProvider.overrideWithValue(true),
            isOfflineProvider.overrideWithValue(false),
            playerStateProvider.overrideWith(_FakePlayer.new),
            downloadBannerSummaryProvider.overrideWithValue(null),
            youtubeAccountProvider.overrideWith(() => accountNotifier),
            youtubeAccountInfoProvider.overrideWith((_) async => sampleAccount),
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

      // Open TV sidebar with Left from first content card.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      final accountBtn = find.byKey(const Key('tv-account-button'));
      final settingsBtn = find.byIcon(LucideIcons.settings);
      expect(accountBtn, findsOneWidget);
      expect(settingsBtn, findsOneWidget);
      expect(
        tester.getTopLeft(accountBtn).dy,
        lessThan(tester.getTopLeft(settingsBtn).dy),
      );

      // Navigate down from Home -> Search -> Library -> Downloads -> Account.
      for (var i = 0; i < 4; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Gabriele'), findsWidgets);
      expect(find.text('@gmstyle'), findsOneWidget);
      expect(find.text('g@example.com'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Move left from Close (autofocused) to Sign out, then press Enter.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(accountNotifier.signOutCalls, 1);
      expect(find.text('@gmstyle'), findsNothing);
    },
  );
}

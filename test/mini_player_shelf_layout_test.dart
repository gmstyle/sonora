import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/core/constants/app_constants.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/player/mini_player_content.dart';
import 'package:sonora/presentation/features/player/player_sheet.dart';
import 'package:sonora/presentation/features/player/player_sheet_mobile.dart';
import 'package:sonora/presentation/features/player/widgets/animated_play_pause_icon.dart';
import 'package:sonora/presentation/providers/cast_provider.dart';
import 'package:sonora/presentation/providers/library_notifier.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';

PlayerState _seed = const PlayerState();

class _FakePlayer extends PlayerNotifier {
  @override
  PlayerState build() => _seed;
}

class _FakeCast extends CastNotifier {
  @override
  Future<CastState> build() async => CastState();
}

void main() {
  final song = MediaItem(id: 'vid1', title: 'Above Water', artist: 'Jah Lil');
  final playing = PlayerState(
    currentSong: song,
    isPlaying: true,
    position: const Duration(minutes: 2, seconds: 32),
    duration: const Duration(minutes: 3, seconds: 30),
  );

  setUp(() {
    _seed = playing;
    SharedPreferences.setMockInitialValues({
      kUseVinylStyleKey: false,
      kReduceEffectsKey: true,
    });
  });

  Future<void> pumpShelf(
    WidgetTester tester, {
    required Size size,
    MediaItem? item,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final current = item ?? song;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            playerStateProvider.overrideWith(_FakePlayer.new),
            likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
            likedEpisodeProvider.overrideWith((ref, id) => Stream.value(null)),
            castStateProvider.overrideWith(_FakeCast.new),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: Scaffold(
                body: SizedBox(
                  width: size.width,
                  height: kMiniPlayerShelfHeight,
                  child: MiniPlayerContent(
                    currentSong: current,
                    playerState: playing,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('wide shelf shows artwork, title, and transport', (tester) async {
    await pumpShelf(tester, size: const Size(1400, 900));
    expect(find.text('Above Water'), findsOneWidget);
    expect(find.text('Jah Lil'), findsOneWidget);
    expect(find.byIcon(LucideIcons.music), findsOneWidget);
    expect(find.byType(AnimatedPlayPauseIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet shelf shows artwork and title', (tester) async {
    await pumpShelf(tester, size: const Size(800, 600));
    expect(find.text('Above Water'), findsOneWidget);
    expect(find.byIcon(LucideIcons.music), findsOneWidget);
    expect(find.byType(AnimatedPlayPauseIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shelf does not overflow on a wide or tablet width', (
    tester,
  ) async {
    await pumpShelf(tester, size: const Size(1280, 800));
    expect(tester.takeException(), isNull);
    await pumpShelf(tester, size: const Size(640, 800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('artist and album labels navigate to catalog', (tester) async {
    final albumSong = MediaItem(
      id: 'vid1',
      title: 'Above Water',
      artist: 'Jah Lil',
      album: 'Night Bloom',
      extras: const {'videoId': 'vid1', 'artistId': 'art1', 'albumId': 'alb1'},
    );
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SizedBox(
              width: 1200,
              height: kMiniPlayerShelfHeight,
              child: MiniPlayerContent(
                currentSong: albumSong,
                playerState: playing,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/artist/:id',
          builder: (_, state) => Text('artist ${state.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/album/:id',
          builder: (_, state) => Text('album ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1400, 900)),
        child: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            playerStateProvider.overrideWith(_FakePlayer.new),
            likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
            likedEpisodeProvider.overrideWith((ref, id) => Stream.value(null)),
            castStateProvider.overrideWith(_FakeCast.new),
          ],
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Night Bloom'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mini-artist-link')));
    await tester.pumpAndSettle();
    expect(find.text('artist art1'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mini-album-link')));
    await tester.pumpAndSettle();
    expect(find.text('album alb1'), findsOneWidget);
  });

  testWidgets('episode artist label opens the podcast', (tester) async {
    final episode = MediaItem(
      id: 'ep1',
      title: 'Episode 12',
      artist: 'Cool Podcast',
      extras: const {
        'contentType': 'episode',
        'podcastBrowseId': 'MPSP123',
        'publishDate': '2024-03-01',
      },
    );
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SizedBox(
              width: 1200,
              height: kMiniPlayerShelfHeight,
              child: MiniPlayerContent(
                currentSong: episode,
                playerState: playing,
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/podcast/:id',
          builder: (_, state) => Text('podcast ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1400, 900)),
        child: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            playerStateProvider.overrideWith(_FakePlayer.new),
            likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
            likedEpisodeProvider.overrideWith((ref, id) => Stream.value(null)),
            castStateProvider.overrideWith(_FakeCast.new),
          ],
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('mini-artist-link')));
    await tester.pumpAndSettle();
    expect(find.text('podcast MPSP123'), findsOneWidget);
  });

  testWidgets('idle shelf occupies no space', (tester) async {
    _seed = const PlayerState();
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playerStateProvider.overrideWith(_FakePlayer.new),
        ],
        child: const MaterialApp(home: Scaffold(body: PlayerSheet())),
      ),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(PlayerSheet)).height, 0);
  });

  testWidgets('active shelf is the full mini-player height', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1400, 900)),
        child: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            playerStateProvider.overrideWith(_FakePlayer.new),
            likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
            likedEpisodeProvider.overrideWith((ref, id) => Stream.value(null)),
            castStateProvider.overrideWith(_FakeCast.new),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: PlayerSheet()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.getSize(find.byType(PlayerSheet)).height,
      kMiniPlayerShelfHeight,
    );
    expect(find.byIcon(LucideIcons.music), findsOneWidget);
  });

  testWidgets('mobile mini player keeps artwork and play', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playerStateProvider.overrideWith(_FakePlayer.new),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PlayerSheetMobile()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Above Water'), findsOneWidget);
    expect(find.byType(AnimatedPlayPauseIcon), findsOneWidget);
    expect(tester.getSize(find.byType(PlayerSheetMobile)).height, 56);
  });
}

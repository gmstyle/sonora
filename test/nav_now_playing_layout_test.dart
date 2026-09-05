import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/player/mini_player_content.dart';
import 'package:sonora/presentation/features/player/nav_now_playing.dart';
import 'package:sonora/presentation/features/player/player_sheet_mobile.dart';
import 'package:sonora/presentation/features/player/widgets/animated_play_pause_icon.dart';
import 'package:sonora/presentation/providers/cast_provider.dart';
import 'package:sonora/presentation/providers/library_notifier.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';
import 'package:sonora/presentation/shared/widgets/vinyl_artwork.dart';

PlayerState _seed = const PlayerState();

class _FakePlayer extends PlayerNotifier {
  @override
  PlayerState build() => _seed;
}

class _ExpandedSidebar extends SidebarCollapsedNotifier {
  @override
  bool build() => false;
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

  Future<void> pumpNav(WidgetTester tester, {required bool expanded}) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playerStateProvider.overrideWith(_FakePlayer.new),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: expanded ? 240 : 72,
                child: NavNowPlaying(expanded: expanded),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('idle nav now-playing occupies no space', (tester) async {
    _seed = const PlayerState();
    await pumpNav(tester, expanded: true);
    expect(find.text('Above Water'), findsNothing);
    expect(tester.getSize(find.byType(NavNowPlaying)).height, 0);
  });

  testWidgets('wide sidebar card shows metadata without transport', (
    tester,
  ) async {
    await pumpNav(tester, expanded: true);
    expect(find.text('Above Water'), findsOneWidget);
    expect(find.text('Jah Lil'), findsOneWidget);
    expect(find.byType(AnimatedPlayPauseIcon), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('collapsed rail disc has no transport row', (tester) async {
    await pumpNav(tester, expanded: false);
    expect(find.byType(AnimatedPlayPauseIcon), findsNothing);
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
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

  testWidgets('wide mini player hides artwork when sidebar is expanded', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1600, 900)),
        child: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            playerStateProvider.overrideWith(_FakePlayer.new),
            sidebarCollapsedProvider.overrideWith(_ExpandedSidebar.new),
            likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
            castStateProvider.overrideWith(_FakeCast.new),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(size: Size(1600, 900)),
              child: Scaffold(
                body: SizedBox(
                  width: 1300,
                  height: 72,
                  child: MiniPlayerContent(
                    currentSong: song,
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
    expect(find.byType(VinylArtwork), findsNothing);
    expect(
      tester
          .widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade))
          .crossFadeState,
      CrossFadeState.showSecond,
    );
    expect(find.byType(AnimatedPlayPauseIcon), findsOneWidget);
  });

  testWidgets('tablet mini player shows title without artwork', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 600)),
        child: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            playerStateProvider.overrideWith(_FakePlayer.new),
            likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
            castStateProvider.overrideWith(_FakeCast.new),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(size: Size(800, 600)),
              child: Scaffold(
                body: SizedBox(
                  width: 720,
                  height: 72,
                  child: MiniPlayerContent(
                    currentSong: song,
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
    expect(find.text('Above Water'), findsOneWidget);
    expect(find.byType(VinylArtwork), findsNothing);
    expect(find.byType(AnimatedPlayPauseIcon), findsOneWidget);
  });

  testWidgets(
    'pixel tablet landscape desktop mini player does not overflow actions',
    (tester) async {
      // Pixel Tablet AVD landscape is ≥1200dp (wide shell), but the floating
      // bar only spans the content pane: 1280 - 240 sidebar - 48 sheet margins.
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1280, 800)),
          child: ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              playerStateProvider.overrideWith(_FakePlayer.new),
              sidebarCollapsedProvider.overrideWith(_ExpandedSidebar.new),
              likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
              castStateProvider.overrideWith(_FakeCast.new),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: const MediaQueryData(size: Size(1280, 800)),
                child: Scaffold(
                  body: SizedBox(
                    width: 991,
                    height: 72,
                    child: MiniPlayerContent(
                      currentSong: song,
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
      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedPlayPauseIcon), findsOneWidget);
    },
  );
}

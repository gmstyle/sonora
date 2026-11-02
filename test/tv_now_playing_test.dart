import 'package:audio_service/audio_service.dart';
import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/core/theme/app_theme.dart';
import 'package:sonora/domain/models/ask_capabilities.dart';
import 'package:sonora/domain/models/ask_mode.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/player/full_player_content.dart';
import 'package:sonora/presentation/features/tv/screens/tv_now_playing_screen.dart';
import 'package:sonora/presentation/features/tv/widgets/tv_mini_player.dart';
import 'package:sonora/presentation/providers/android_tv_provider.dart';
import 'package:sonora/presentation/providers/connectivity_provider.dart';
import 'package:sonora/presentation/providers/equalizer_provider.dart';
import 'package:sonora/presentation/providers/library_notifier.dart';
import 'package:sonora/presentation/providers/on_device_llm_provider.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';

PlayerState _seed = const PlayerState();

class _FakePlayer extends PlayerNotifier {
  @override
  PlayerState build() => _seed;
}

class _FakeEq extends EqualizerNotifier {
  @override
  EqualizerState build() => const EqualizerState(
    enabled: false,
    gains: [0, 0, 0, 0, 0],
    preset: 'flat',
  );
}

void main() {
  final song = MediaItem(
    id: 'vid1',
    title: 'Above Water',
    artist: 'Jah Lil',
    duration: const Duration(minutes: 3),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _seed = PlayerState(
      currentSong: song,
      isPlaying: true,
      position: const Duration(minutes: 1),
      duration: const Duration(minutes: 3),
      isQueueSynced: true,
      queue: [song],
    );
  });

  Future<void> pumpNp(WidgetTester tester, {bool offline = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAndroidTvProvider.overrideWithValue(true),
          sharedPreferencesProvider.overrideWithValue(prefs),
          playerStateProvider.overrideWith(_FakePlayer.new),
          equalizerNotifierProvider.overrideWith(_FakeEq.new),
          isOfflineProvider.overrideWithValue(offline),
          likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
          likedEpisodeProvider.overrideWith((ref, id) => Stream.value(null)),
          askCapabilitiesProvider.overrideWith(
            (ref) async => const AskCapabilities(AskLlmBackend.none),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: Dpad.wrap(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TvNowPlayingScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'TV NP shows track and opens queue in-place without full player',
    (tester) async {
      await pumpNp(tester);

      expect(find.text('Above Water'), findsOneWidget);
      expect(find.text('Jah Lil'), findsOneWidget);
      expect(find.byType(FullPlayerContent), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TvNowPlayingScreen)),
      );
      expect(container.read(playerSubViewProvider), PlayerSubView.none);

      await tester.tap(find.byKey(const Key('tv_np_queue')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(playerSubViewProvider), PlayerSubView.queue);
      expect(find.byType(FullPlayerContent), findsNothing);
    },
  );

  testWidgets('TV NP PopScope blocks pop while a sub-view is open', (
    tester,
  ) async {
    await pumpNp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TvNowPlayingScreen)),
    );
    container.read(playerSubViewProvider.notifier).set(PlayerSubView.queue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final popFinder = find.byWidgetPredicate((w) => w is PopScope);
    final blocked = tester.widget<PopScope>(popFinder);
    expect(blocked.canPop, isFalse);

    container.read(playerSubViewProvider.notifier).set(PlayerSubView.none);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final open = tester.widget<PopScope>(popFinder);
    expect(open.canPop, isTrue);
  });

  testWidgets('TV mini player OK target opens NP route', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAndroidTvProvider.overrideWithValue(true),
          sharedPreferencesProvider.overrideWithValue(prefs),
          playerStateProvider.overrideWith(_FakePlayer.new),
          equalizerNotifierProvider.overrideWith(_FakeEq.new),
          isOfflineProvider.overrideWithValue(false),
          likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
          likedEpisodeProvider.overrideWith((ref, id) => Stream.value(null)),
          askCapabilitiesProvider.overrideWith(
            (ref) async => const AskCapabilities(AskLlmBackend.none),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: Dpad.wrap(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TvMiniPlayer()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('tv_mini_open_np')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tv_mini_open_np')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TvNowPlayingScreen), findsOneWidget);
  });
}

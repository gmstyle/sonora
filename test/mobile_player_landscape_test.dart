import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/core/theme/player_colors.dart';
import 'package:sonora/domain/models/ask_mode.dart';
import 'package:sonora/domain/models/ask_capabilities.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/player/layouts/mobile_player_layout.dart';
import 'package:sonora/presentation/providers/cast_provider.dart';
import 'package:sonora/presentation/providers/library_notifier.dart';
import 'package:sonora/presentation/providers/on_device_llm_provider.dart';
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

  setUp(() {
    _seed = PlayerState(
      currentSong: song,
      isPlaying: true,
      position: const Duration(minutes: 1),
      duration: const Duration(minutes: 3),
    );
    SharedPreferences.setMockInitialValues({kReduceEffectsKey: true});
  });

  Future<void> pumpPlayer(WidgetTester tester, {required Size size}) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          playerStateProvider.overrideWith(_FakePlayer.new),
          castStateProvider.overrideWith(_FakeCast.new),
          likedSongProvider.overrideWith((ref, id) => Stream.value(null)),
          likedEpisodeProvider.overrideWith((ref, id) => Stream.value(null)),
          askCapabilitiesProvider.overrideWith(
            (ref) async => const AskCapabilities(AskLlmBackend.none),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(extensions: [PlayerColors.standard()]),
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return MobilePlayerLayout(
                    artworkKey: GlobalKey(),
                    currentSong: song,
                    videoId: song.id,
                    artUrl: null,
                    albumName: 'North',
                    playerState: _seed,
                    playerNotifier: ref.read(playerStateProvider.notifier),
                    hasSleepTimer: false,
                    availHeight: size.height,
                    availWidth: size.width,
                    bottomInset: 0,
                    activeView: PlayerSubView.none,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('portrait keeps Up Next under the disc', (tester) async {
    await pumpPlayer(tester, size: const Size(400, 800));

    expect(find.text('AUTOPLAY'), findsOneWidget);
    expect(find.text('Above Water'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape parks transport on the right and drops Up Next', (
    tester,
  ) async {
    await pumpPlayer(tester, size: const Size(800, 360));

    expect(find.text('AUTOPLAY'), findsNothing);
    expect(find.text('Above Water'), findsOneWidget);
    expect(find.text('PLAYING FROM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

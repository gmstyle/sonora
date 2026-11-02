import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/core/theme/app_theme.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/home/providers/home_provider.dart';
import 'package:sonora/presentation/features/library/widgets/sonora_wrapped_view.dart';
import 'package:sonora/presentation/features/tv/screens/tv_home_screen.dart';
import 'package:sonora/presentation/providers/android_tv_provider.dart';
import 'package:sonora/presentation/providers/connectivity_provider.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';
import 'package:sonora/presentation/providers/stats_provider.dart';

class _FakePlayer extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

class _WrappedStats extends StatsNotifier {
  @override
  StatsState build() => StatsState(
    isLoading: false,
    totalDurationMinutes: 120,
    isWrappedAvailable: true,
  );
}

class _UnavailableStats extends StatsNotifier {
  @override
  StatsState build() => StatsState(isLoading: false, isWrappedAvailable: false);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SonoraWrappedView on TV shows D-pad nav and hides share', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final stats = _WrappedStats().build();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAndroidTvProvider.overrideWithValue(true),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: Dpad.wrap(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SonoraWrappedView(stats: stats),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sonora Wrapped'), findsWidgets);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Close'), findsWidgets);
    expect(find.text('Share'), findsNothing);
  });

  testWidgets('TvHomeScreen shows Wrapped shelf when available', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAndroidTvProvider.overrideWithValue(true),
          sharedPreferencesProvider.overrideWithValue(prefs),
          playerStateProvider.overrideWith(_FakePlayer.new),
          isOfflineProvider.overrideWithValue(false),
          statsProvider.overrideWith(_WrappedStats.new),
          homeBaseSectionsProvider.overrideWith((ref) async => const []),
          recentHistoryProvider.overrideWith((ref) async => const []),
          homeRandomPlaylistsProvider.overrideWith((ref) async => const []),
          homeRandomArtistsProvider.overrideWith((ref) async => const []),
          homeRandomAlbumsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: Dpad.wrap(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TvHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sonora Wrapped'), findsOneWidget);
    expect(find.text('Launch your Wrapped'), findsOneWidget);
  });

  testWidgets('TvHomeScreen hides Wrapped shelf when unavailable', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAndroidTvProvider.overrideWithValue(true),
          sharedPreferencesProvider.overrideWithValue(prefs),
          playerStateProvider.overrideWith(_FakePlayer.new),
          isOfflineProvider.overrideWithValue(false),
          statsProvider.overrideWith(_UnavailableStats.new),
          homeBaseSectionsProvider.overrideWith((ref) async => const []),
          recentHistoryProvider.overrideWith((ref) async => const []),
          homeRandomPlaylistsProvider.overrideWith((ref) async => const []),
          homeRandomArtistsProvider.overrideWith((ref) async => const []),
          homeRandomAlbumsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: Dpad.wrap(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TvHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sonora Wrapped'), findsNothing);
    expect(find.text('Launch your Wrapped'), findsNothing);
  });
}

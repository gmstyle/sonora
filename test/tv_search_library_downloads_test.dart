import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/core/theme/app_theme.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/library/providers/library_provider.dart';
import 'package:sonora/presentation/features/search/providers/search_provider.dart';
import 'package:sonora/presentation/features/tv/screens/tv_downloads_screen.dart';
import 'package:sonora/presentation/features/tv/screens/tv_library_screen.dart';
import 'package:sonora/presentation/features/tv/screens/tv_search_screen.dart';
import 'package:sonora/presentation/providers/android_tv_provider.dart';
import 'package:sonora/presentation/providers/connectivity_provider.dart';
import 'package:sonora/presentation/providers/download_provider.dart';
import 'package:sonora/presentation/providers/library_notifier.dart';
import 'package:sonora/presentation/providers/on_device_llm_provider.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';
import 'package:sonora/presentation/providers/stats_provider.dart';

class _FakePlayer extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

class _FakeLibraryNotifier extends LibraryNotifier {
  @override
  void build() {}

  @override
  Future<void> refreshPlaylistThumbnailsIfNeeded() async {}
}

class _FakeStats extends StatsNotifier {
  @override
  StatsState build() => StatsState(
    isLoading: false,
    totalDurationMinutes: 42,
    topSongs: const [],
    topArtists: const [],
    topEpisodes: const [],
    topPodcasts: const [],
  );
}

class _EmptyDownloads extends DownloadsNotifier {
  @override
  Map<String, ActiveDownload> build() => {};
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  List<Override> baseOverrides(SharedPreferences p) => [
    isAndroidTvProvider.overrideWithValue(true),
    sharedPreferencesProvider.overrideWithValue(p),
    playerStateProvider.overrideWith(_FakePlayer.new),
    isOfflineProvider.overrideWithValue(false),
    libraryNotifierProvider.overrideWith(_FakeLibraryNotifier.new),
  ];

  group('TvSearchScreen', () {
    testWidgets('shows Ask chip and empty state', (tester) async {
      final p = await prefs();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(p),
            askLlmReadyProvider.overrideWith((ref) async => true),
            searchResultsProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder: Dpad.wrap(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TvSearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ask'), findsOneWidget);
      expect(find.text('Search for music'), findsOneWidget);
    });

    testWidgets('shows filter chips after an active query', (tester) async {
      final p = await prefs();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(p),
            askLlmReadyProvider.overrideWith((ref) async => true),
            searchResultsProvider.overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder: Dpad.wrap(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TvSearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TvSearchScreen)),
      );
      container.read(searchQueryProvider.notifier).update('beatles');
      await container
          .read(activeSearchQueryProvider.notifier)
          .activate('beatles', persistHistory: false);
      await tester.pumpAndSettle();

      expect(find.text('Ask'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Songs'), findsOneWidget);
      expect(find.text('No results'), findsOneWidget);
    });
  });

  group('TvLibraryScreen', () {
    List<Override> libraryOverrides(SharedPreferences p) => [
      ...baseOverrides(p),
      likedSongsProvider.overrideWith(
        (ref) => Stream.value(const <LikedSongModel>[]),
      ),
      likedAlbumsProvider.overrideWith(
        (ref) => Stream.value(const <LikedAlbumModel>[]),
      ),
      followedArtistsProvider.overrideWith(
        (ref) => Stream.value(const <FollowedArtistModel>[]),
      ),
      playlistsProvider.overrideWith(
        (ref) => Stream.value(const <LocalPlaylistModel>[]),
      ),
      likedPlaylistsProvider.overrideWith(
        (ref) => Stream.value(const <LikedPlaylistModel>[]),
      ),
      likedPodcastsProvider.overrideWith(
        (ref) => Stream.value(const <LikedPodcastModel>[]),
      ),
      libraryHistoryProvider.overrideWith(
        (ref) => Stream.value(const <HistoryModel>[]),
      ),
      statsProvider.overrideWith(_FakeStats.new),
    ];

    testWidgets('exposes mixes history and stats sections', (tester) async {
      final p = await prefs();
      await tester.pumpWidget(
        ProviderScope(
          overrides: libraryOverrides(p),
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder: Dpad.wrap(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TvLibraryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mixes'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
    });

    testWidgets('playlists section shows create and import actions', (
      tester,
    ) async {
      final p = await prefs();
      await tester.pumpWidget(
        ProviderScope(
          overrides: libraryOverrides(p),
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder: Dpad.wrap(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TvLibraryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();

      expect(find.text('Create Playlist'), findsOneWidget);
      expect(find.text('Import Playlist'), findsOneWidget);
    });
  });

  group('TvDownloadsScreen', () {
    testWidgets('shows empty state with search CTA', (tester) async {
      final p = await prefs();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...baseOverrides(p),
            activeDownloadsProvider.overrideWith(_EmptyDownloads.new),
            allDownloadsProvider.overrideWith(
              (ref) => Stream.value(const <DownloadModel>[]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder: Dpad.wrap(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TvDownloadsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No downloads yet'), findsOneWidget);
      expect(find.text('Go to Search'), findsOneWidget);
    });
  });
}

import 'dart:async';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/domain/models/library_models.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/home/layouts/home_feed_layout.dart';
import 'package:sonora/presentation/features/home/layouts/home_layout_metrics.dart';
import 'package:sonora/presentation/features/home/providers/home_provider.dart';
import 'package:sonora/presentation/features/home/widgets/home_section_renderer.dart';
import 'package:sonora/presentation/providers/connectivity_provider.dart';
import 'package:sonora/presentation/providers/on_device_llm_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';
import 'package:sonora/presentation/providers/stats_provider.dart';

HomeSection _shelf(String title) {
  return HomeSection(
    title: title,
    contents: [
      AlbumDetailed(
        type: 'ALBUM',
        albumId: 'album-$title',
        playlistId: 'pl-$title',
        name: '$title album',
        thumbnails: const [],
      ),
    ],
  );
}

class _IdleStats extends StatsNotifier {
  @override
  StatsState build() => StatsState(isLoading: false);
}

class _SelectedChip extends HomeSelectedChipParamsNotifier {
  @override
  String? build() => 'relax';
}

Future<void> _pump(
  WidgetTester tester, {
  required BrowseHomeResult home,
  required List<HomeSection> baseSections,
  required Future<List<HomeSection>> Function(Ref ref) editorial,
  bool offline = false,
  HomeSelectedChipParamsNotifier Function()? selectedChip,
  Size view = const Size(800, 480),
}) async {
  tester.view.physicalSize = view;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isOfflineProvider.overrideWithValue(offline),
        askLlmReadyProvider.overrideWith((ref) async => false),
        statsProvider.overrideWith(_IdleStats.new),
        recentHistoryProvider.overrideWith((ref) async => <HistoryModel>[]),
        homeRandomPlaylistsProvider.overrideWith((ref) async => <dynamic>[]),
        homeRandomArtistsProvider.overrideWith(
          (ref) async => <FollowedArtistModel>[],
        ),
        homeRandomAlbumsProvider.overrideWith(
          (ref) async => <LikedAlbumModel>[],
        ),
        homeRandomNewReleasesProvider.overrideWith(
          (ref) async => <AlbumDetailed>[],
        ),
        homeDiscoverProvider.overrideWith((ref) async => <UpNextsDetails>[]),
        homeSimilarArtistsProvider.overrideWith(
          (ref) async => <ArtistDetailed>[],
        ),
        homeBaseResultProvider.overrideWith((ref) async => home),
        homeBaseSectionsProvider.overrideWith((ref) async => baseSections),
        homeEditorialSectionsProvider.overrideWith(editorial),
        if (selectedChip != null)
          homeSelectedChipParamsProvider.overrideWith(selectedChip),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(brightness: Brightness.light),
        home: HomeFeedLayout(
          metrics: HomeLayoutMetrics.fromWidth(800, shortestSide: 500),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Finder get _feedScroll => find.byWidgetPredicate(
  (widget) =>
      widget is Scrollable && widget.axisDirection == AxisDirection.down,
);

double _feedOffset(WidgetTester tester) {
  return tester.state<ScrollableState>(_feedScroll).position.pixels;
}

void main() {
  final quickPicks = _shelf('Quick picks');
  final evening = _shelf('Evening drive');
  final home = BrowseHomeResult(
    chips: [BrowseChip(title: 'Relax', params: 'relax', isSelected: false)],
    sections: [quickPicks],
  );

  testWidgets('a chip replaces the personal feed and All restores it', (
    tester,
  ) async {
    await _pump(
      tester,
      home: home,
      baseSections: [
        HomeSection(title: 'Unused', contents: const []),
        quickPicks,
      ],
      editorial: (ref) async {
        final params = ref.watch(homeSelectedChipParamsProvider);
        if (params == null) return [quickPicks];
        return [evening];
      },
    );

    expect(find.byType(HomeChipsBar), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Evening drive'), findsNothing);
    expect(find.text('Editorial'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Quick picks'),
      300,
      scrollable: _feedScroll,
    );
    expect(_feedOffset(tester), greaterThan(0));

    await tester.tap(find.text('Relax'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Explore'), findsNothing);
    expect(find.text('Quick picks'), findsNothing);
    expect(find.text('Evening drive'), findsOneWidget);
    expect(_feedOffset(tester), 0);

    await tester.tap(find.text('All'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Evening drive'), findsNothing);
    expect(_feedOffset(tester), 0);
    await tester.scrollUntilVisible(
      find.text('Quick picks'),
      300,
      scrollable: _feedScroll,
    );
  });

  testWidgets('a loading chip feed drops the previous shelves', (tester) async {
    final relaxFeed = Completer<List<HomeSection>>();
    addTearDown(() {
      if (!relaxFeed.isCompleted) {
        relaxFeed.complete([evening]);
      }
    });

    await _pump(
      tester,
      home: home,
      baseSections: [
        HomeSection(title: 'Unused', contents: const []),
        quickPicks,
      ],
      editorial: (ref) {
        final params = ref.watch(homeSelectedChipParamsProvider);
        if (params == null) return Future.value([quickPicks]);
        return relaxFeed.future;
      },
    );

    await tester.scrollUntilVisible(
      find.text('Quick picks'),
      300,
      scrollable: _feedScroll,
    );

    await tester.tap(find.text('Relax'));
    await tester.pump();

    expect(find.text('Explore'), findsNothing);
    expect(find.text('Quick picks'), findsNothing);
    expect(find.text('Evening drive'), findsNothing);
    expect(find.byType(HomeEditorialLoading), findsOneWidget);

    relaxFeed.complete([evening]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Evening drive'), findsOneWidget);
    expect(find.text('Explore'), findsNothing);
  });

  testWidgets('offline hides the chip row and keeps the personal feed', (
    tester,
  ) async {
    await _pump(
      tester,
      offline: true,
      selectedChip: _SelectedChip.new,
      home: home,
      baseSections: [quickPicks],
      editorial: (ref) async => [evening],
    );

    expect(find.byType(HomeChipsBar), findsNothing);
    expect(find.text('Evening drive'), findsNothing);
    expect(find.textContaining('No internet connection'), findsOneWidget);
    expect(find.text('Your Mixes'), findsOneWidget);
  });
}

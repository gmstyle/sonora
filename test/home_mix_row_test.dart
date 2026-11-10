import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/core/constants/app_constants.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/home/layouts/home_layout_metrics.dart';
import 'package:sonora/presentation/features/home/widgets/home_quick_row.dart';
import 'package:sonora/presentation/providers/on_device_llm_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';
import 'package:sonora/presentation/providers/stats_provider.dart';
import 'package:sonora/presentation/shared/widgets/smart_mix_card.dart';

class _IdleStats extends StatsNotifier {
  @override
  StatsState build() => StatsState(isLoading: false);
}

Future<void> _pump(WidgetTester tester, HomeLayoutMetrics metrics) async {
  tester.view.physicalSize = Size(metrics.contentWidth, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        statsProvider.overrideWith(_IdleStats.new),
        askLlmReadyProvider.overrideWith((ref) async => false),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HomeQuickRow(
            historyAsync: const AsyncData<List<dynamic>>([]),
            metrics: metrics,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('an empty tablet resume row keeps mixes on the right', (
    tester,
  ) async {
    const width = 1100.0;
    final metrics = HomeLayoutMetrics.fromWidth(width, shortestSide: 800);
    await _pump(tester, metrics);

    final placeholder = find.byKey(const Key('home-continue-placeholder'));
    expect(placeholder, findsOneWidget);
    expect(find.text('Continue Listening'), findsOneWidget);
    expect(
      find.text('Your recently played songs will appear here.'),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byType(SmartMixCard).first).dx,
      greaterThan(tester.getTopRight(placeholder).dx),
    );
  });

  testWidgets('a wide mixes column still stops at the max tile', (
    tester,
  ) async {
    const width = 1700.0;
    final metrics = HomeLayoutMetrics.fromWidth(width, shortestSide: 800);
    await _pump(tester, metrics);

    final cards = tester
        .widgetList<SmartMixCard>(find.byType(SmartMixCard))
        .toList();
    expect(cards, hasLength(3));
    expect(
      cards.every((card) => card.cardWidth == kHomeMixCardMaxWidth),
      isTrue,
    );
  });

  testWidgets('the empty card opens search', (tester) async {
    final metrics = HomeLayoutMetrics.fromWidth(1100, shortestSide: 800);
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: HomeQuickRow(
              historyAsync: const AsyncData<List<dynamic>>([]),
              metrics: metrics,
            ),
          ),
        ),
        GoRoute(
          path: '/search',
          builder: (_, _) => const Text('search-destination'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          statsProvider.overrideWith(_IdleStats.new),
          askLlmReadyProvider.overrideWith((ref) async => false),
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
    await tester.pump();

    await tester.tap(find.text('Go to Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('search-destination'), findsOneWidget);
  });

  testWidgets('a phone row still fills the width', (tester) async {
    const width = 360.0;
    final metrics = HomeLayoutMetrics.fromWidth(width, shortestSide: 360);
    await _pump(tester, metrics);

    expect(find.byKey(const Key('home-continue-placeholder')), findsNothing);
    final card = tester.widget<SmartMixCard>(find.byType(SmartMixCard).first);
    final expected = (width - metrics.horizontalPadding * 2 - 16) / 3;
    expect(card.cardWidth, closeTo(expected, 0.01));
    expect(
      tester.getTopLeft(find.byType(SmartMixCard).first).dx,
      metrics.horizontalPadding,
    );
  });
}

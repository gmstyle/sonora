import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/tv/layouts/tv_shell.dart';
import 'package:sonora/presentation/features/tv/tv_metrics.dart';
import 'package:sonora/presentation/providers/android_tv_provider.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';
import 'package:sonora/presentation/shared/widgets/dock_status_banners.dart';
import 'package:sonora/presentation/shared/widgets/playlist_import_job_host.dart';

class _FakePlayerNotifier extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

Future<({ProviderContainer container, FocusNode contentFocus})> _pumpTvShell(
  WidgetTester tester,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final contentFocus = FocusNode(debugLabel: 'tv-test-content');
  addTearDown(contentFocus.dispose);

  final router = GoRouter(
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return TvShell(navigationShell: navigationShell);
        },
        branches: [
          for (final path in ['/', '/search', '/library', '/downloads'])
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (context, state) {
                    final child = const Center(child: Text('branch'));
                    // Only the active home branch needs a focus target for
                    // the collapse test; avoid sharing one FocusNode.
                    if (path == '/') {
                      return Focus(focusNode: contentFocus, child: child);
                    }
                    return child;
                  },
                ),
              ],
            ),
        ],
      ),
    ],
  );

  final container = ProviderContainer(
    overrides: [
      isAndroidTvProvider.overrideWithValue(true),
      playerStateProvider.overrideWith(_FakePlayerNotifier.new),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container: container, contentFocus: contentFocus);
}

FocusNode _findFocusNode(String debugLabel) {
  FocusNode? found;
  void walk(FocusNode node) {
    if (found != null) return;
    if (node.debugLabel == debugLabel) {
      found = node;
      return;
    }
    for (final child in node.children) {
      walk(child);
    }
  }

  walk(FocusManager.instance.rootScope);
  expect(found, isNotNull, reason: 'missing FocusNode $debugLabel');
  return found!;
}

void main() {
  test('TvMetrics matches P1 10-foot chrome targets', () {
    expect(TvMetrics.sidebarCollapsedWidth, 72);
    expect(TvMetrics.sidebarExpandedWidth, 220);
    expect(TvMetrics.cardWidth, inInclusiveRange(200, 220));
    expect(TvMetrics.cardArtSize, inInclusiveRange(200, 220));
    expect(TvMetrics.focusScale, 1.12);
    expect(TvMetrics.overscan, greaterThanOrEqualTo(32));
    expect(TvMetrics.horizontalPadding, TvMetrics.overscan);
  });

  testWidgets('TvShell shows sidebar destinations when nav focused', (
    tester,
  ) async {
    await _pumpTvShell(tester);
    // DpadFocusable debugLabel overrides the FocusNode label to nav:<title>.
    _findFocusNode('nav:Home').requestFocus();
    await tester.pumpAndSettle();

    expect(find.text('SONORA'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('TvShell mounts dock banners host and import job host', (
    tester,
  ) async {
    await _pumpTvShell(tester);

    expect(find.byType(DockStatusBanners), findsOneWidget);
    expect(find.byType(PlaylistImportJobHost), findsOneWidget);
  });

  testWidgets('TvShell rail collapses when content holds focus', (
    tester,
  ) async {
    final pumped = await _pumpTvShell(tester);

    _findFocusNode('nav:Home').requestFocus();
    await tester.pumpAndSettle();

    expect(find.text('SONORA'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(_findFocusNode('tv-sidebar-scope').hasFocus, isTrue);

    // Move focus into branch content (as shelves do after leaving the rail).
    pumped.contentFocus.requestFocus();
    await tester.pumpAndSettle();

    expect(_findFocusNode('tv-sidebar-scope').hasFocus, isFalse);
    // Collapsed: brand wordmark and destination labels hide.
    expect(find.text('SONORA'), findsNothing);
    expect(find.text('Home'), findsNothing);
    expect(find.text('branch'), findsOneWidget);
  });
}

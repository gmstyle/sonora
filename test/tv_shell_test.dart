import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/tv/layouts/tv_shell.dart';
import 'package:sonora/presentation/providers/android_tv_provider.dart';
import 'package:sonora/presentation/providers/player_provider.dart';

class _FakePlayerNotifier extends PlayerNotifier {
  @override
  PlayerState build() => const PlayerState();
}

void main() {
  testWidgets('TvShell shows sidebar destinations', (tester) async {
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
                    builder:
                        (context, state) =>
                            const Center(child: Text('branch')),
                  ),
                ],
              ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isAndroidTvProvider.overrideWithValue(true),
          playerStateProvider.overrideWith(_FakePlayerNotifier.new),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SONORA'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}

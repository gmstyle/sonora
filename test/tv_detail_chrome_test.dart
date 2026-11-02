import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/tv/widgets/tv_focusable.dart';
import 'package:sonora/presentation/features/tv/widgets/tv_left_to_sidebar.dart';
import 'package:sonora/presentation/providers/android_tv_provider.dart';
import 'package:sonora/presentation/providers/download_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';
import 'package:sonora/presentation/shared/widgets/detail_actions_bar.dart';
import 'package:sonora/presentation/shared/widgets/song_tile.dart';

FocusNode? _findFocusNode(String debugLabel) {
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
  return found;
}

Future<ProviderContainer> _pumpTv(
  WidgetTester tester, {
  required Widget child,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      isAndroidTvProvider.overrideWithValue(true),
      sharedPreferencesProvider.overrideWithValue(prefs),
      downloadedIdsProvider.overrideWith((ref) => <String>{}),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'DetailActionsBar on TV mounts focusable Play-dominant controls',
    (tester) async {
      await _pumpTv(
        tester,
        child: DetailActionsBar(
          secondary: [
            DetailAction(
              id: DetailActionId.queue,
              icon: LucideIcons.listMusic,
              label: 'Queue',
              tooltip: 'Queue',
              onPressed: () {},
            ),
            DetailAction(
              id: DetailActionId.save,
              icon: Icons.favorite_border,
              label: 'Like',
              tooltip: 'Like',
              onPressed: () {},
            ),
          ],
          onPlay: () {},
          playLabel: 'Play all',
          onShuffle: () {},
          shuffleLabel: 'Shuffle',
          alwaysShowOverflow: true,
          onOverflow: () {},
        ),
      );

      expect(find.byType(TvFocusable), findsNWidgets(5));
      expect(_findFocusNode('detail-action:play'), isNotNull);
      expect(_findFocusNode('detail-action:shuffle'), isNotNull);
      expect(_findFocusNode('detail-action:queue'), isNotNull);
      expect(_findFocusNode('detail-action:save'), isNotNull);
      expect(_findFocusNode('detail-action:more'), isNotNull);

      // Play is the dominant filled control on the TV bar.
      expect(find.widgetWithText(FilledButton, 'Play all'), findsOneWidget);
      expect(find.text('Shuffle'), findsOneWidget);
    },
  );

  testWidgets('SongTile on TV exposes a D-pad focus target', (tester) async {
    var selected = false;
    await _pumpTv(
      tester,
      child: SongTile(
        videoId: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        onTap: () => selected = true,
      ),
    );

    final node = _findFocusNode('song-tile:dQw4w9WgXcQ');
    expect(node, isNotNull);
    expect(find.byType(MaybeTvFocusable), findsOneWidget);

    // Activate via the underlying ListTile tap path (same callback as Select).
    await tester.tap(find.text('Never Gonna Give You Up'));
    await tester.pump();
    expect(selected, isTrue);
  });

  testWidgets('TvLeftToSidebar wraps pushed catalog content', (tester) async {
    await _pumpTv(
      tester,
      child: const TvLeftToSidebar(memoryKey: 'tv/album', child: Text('album')),
    );
    expect(find.byType(TvLeftToSidebar), findsOneWidget);
    expect(find.text('album'), findsOneWidget);
  });
}

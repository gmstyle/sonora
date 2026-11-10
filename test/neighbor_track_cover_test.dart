import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/core/theme/player_colors.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/player/layouts/wide_player_layout.dart';

void main() {
  testWidgets('neighbor cover shows the track title and skips on tap', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    var tapped = false;
    const title = 'Night Drive';

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PlayerColors.standard()]),
        home: Scaffold(
          body: NeighborTrackCover(
            item: const MediaItem(id: 'v', title: title),
            size: 160,
            semanticsLabel: l10n.previousTrackNamed(title),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text(title), findsOneWidget);
    expect(find.bySemanticsLabel('Previous, Night Drive'), findsOneWidget);

    final text = tester.widget<Text>(find.text(title));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.textAlign, TextAlign.center);
    expect(text.style?.fontWeight, FontWeight.w600);
    expect(text.style?.color, PlayerColors.standard().titlePrimary);
    expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, title);

    await tester.tap(find.text(title));
    expect(tapped, isTrue);
  });

  testWidgets('the next cover names the upcoming track', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('it'));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PlayerColors.standard()]),
        home: Scaffold(
          body: NeighborTrackCover(
            item: const MediaItem(id: 'n', title: 'Alba'),
            size: 160,
            semanticsLabel: l10n.nextTrackNamed('Alba'),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Alba'), findsOneWidget);
    expect(find.bySemanticsLabel('Successivo, Alba'), findsOneWidget);
  });
}

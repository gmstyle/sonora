import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/core/theme/player_colors.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/player/layouts/wide_player_layout.dart';
import 'package:sonora/presentation/shared/widgets/explicit_badge.dart';

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
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.style?.fontWeight, FontWeight.w700);
    expect(text.style?.color, PlayerColors.standard().titlePrimary);
    expect(find.byType(ExplicitBadge), findsNothing);
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

  testWidgets('neighbor cover shows the artist and the explicit mark', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PlayerColors.standard()]),
        home: Scaffold(
          body: NeighborTrackCover(
            item: const MediaItem(
              id: 'v',
              title: 'Night Drive',
              artist: 'Ada',
              extras: {'isExplicit': true},
            ),
            size: 180,
            semanticsLabel: l10n.previousTrackNamed('Night Drive'),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Night Drive'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.byType(ExplicitBadge), findsOneWidget);
    expect(find.bySemanticsLabel('Previous, Night Drive, Ada'), findsOneWidget);
    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).message,
      'Night Drive · Ada',
    );

    final artist = tester.widget<Text>(find.text('Ada'));
    expect(artist.maxLines, 1);
    expect(artist.style?.fontWeight, FontWeight.w600);
    expect(artist.style?.color, PlayerColors.standard().titleSecondary);
  });
}

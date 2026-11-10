import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/presentation/shared/widgets/header_credit_line.dart';

Future<GoRouter> _pump(WidgetTester tester, List<CreditSpan> credits) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: HeaderCreditLine(credits: credits)),
      ),
      GoRoute(
        path: '/artist/:id',
        builder: (_, state) => Text('artist ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/podcast/:id',
        builder: (_, state) => Text('podcast ${state.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(locale: const Locale('en'), routerConfig: router),
  );
  await tester.pump();
  return router;
}

void main() {
  testWidgets('each credited artist opens its own page', (tester) async {
    await _pump(
      tester,
      artistCreditSpans([
        ArtistBasic(name: 'Ada', artistId: 'ada'),
        ArtistBasic(name: 'Be', artistId: 'be'),
        ArtistBasic(name: 'Cy', artistId: 'cy'),
      ]),
    );

    expect(
      tester.widget<Text>(find.byType(Text)).textSpan!.toPlainText(),
      'Ada, Be & Cy',
    );

    final paragraph = tester.renderObject<RenderParagraph>(find.byType(Text));
    final plain = paragraph.text.toPlainText();
    final start = plain.indexOf('Be');
    final box = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + 2),
        )
        .first;
    await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('artist be'), findsOneWidget);
  });

  testWidgets('a credit without an id stays plain text', (tester) async {
    await _pump(tester, artistCreditSpans([ArtistBasic(name: 'Ada')]));

    await tester.tap(find.text('Ada'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Ada'), findsOneWidget);
    expect(find.textContaining('artist '), findsNothing);
  });

  testWidgets('a show name opens the podcast', (tester) async {
    await _pump(tester, [
      const CreditSpan('Night Shift', route: '/podcast/show'),
    ]);

    await tester.tap(find.text('Night Shift'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('podcast show'), findsOneWidget);
  });
}

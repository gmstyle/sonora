import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/presentation/features/player/widgets/overflow_title.dart';

void main() {
  Widget wrap(Widget child, {required double width}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(width: width, child: child),
      ),
    );
  }

  testWidgets('a title that fits is a single line', (tester) async {
    await tester.pumpWidget(
      wrap(
        const OverflowTitle(text: 'Short', style: TextStyle(fontSize: 24)),
        width: 400,
      ),
    );

    expect(find.text('Short'), findsOneWidget);
  });

  testWidgets('an overflowing title is duplicated so it can scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const OverflowTitle(
          text: 'A very long track title that cannot fit',
          style: TextStyle(fontSize: 24),
        ),
        width: 80,
      ),
    );

    expect(
      find.text('A very long track title that cannot fit'),
      findsNWidgets(2),
    );
  });

  testWidgets('reduceEffects keeps an overflowing title as one line', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const OverflowTitle(
          text: 'A very long track title that cannot fit',
          style: TextStyle(fontSize: 24),
          reduceEffects: true,
        ),
        width: 80,
      ),
    );

    expect(
      find.text('A very long track title that cannot fit'),
      findsOneWidget,
    );
  });
}

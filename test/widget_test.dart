import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/main.dart';

void main() {
  testWidgets('App shows Hello Sonora', (WidgetTester tester) async {
    await tester.pumpWidget(const SonoraApp());
    await tester.pumpAndSettle();

    expect(find.text('Sonora'), findsOneWidget);
    expect(find.text('Hello Sonora'), findsOneWidget);
  });
}

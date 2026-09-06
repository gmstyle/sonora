import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/player/widgets/progress_bar_widget.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 80, child: child)),
    );
  }

  Finder track() => find.descendant(
    of: find.byType(ProgressBarWidget),
    matching: find.byType(CustomPaint),
  );

  testWidgets('compact track has no times and no seek without onSeek', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const ProgressBarWidget(
          position: Duration(seconds: 30),
          duration: Duration(minutes: 3, seconds: 30),
          isPlaying: true,
          density: ProgressBarDensity.compact,
        ),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(ProgressBarWidget),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
    expect(track(), findsOneWidget);
    expect(find.text('0:30'), findsNothing);
  });

  testWidgets('comfortable track seeks with times beside', (tester) async {
    Duration? sought;
    await tester.pumpWidget(
      wrap(
        ProgressBarWidget(
          position: const Duration(minutes: 2, seconds: 32),
          duration: const Duration(minutes: 3, seconds: 30),
          isPlaying: true,
          density: ProgressBarDensity.comfortable,
          onSeek: (pos) => sought = pos,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('2:32'), findsOneWidget);
    expect(find.text('-0:58'), findsOneWidget);

    await tester.tap(track());
    await tester.pump();
    expect(sought, isNotNull);
    expect(sought!.inSeconds, inInclusiveRange(80, 130));
  });

  testWidgets('expanded track seeks with times below', (tester) async {
    Duration? sought;
    await tester.pumpWidget(
      wrap(
        ProgressBarWidget(
          position: const Duration(minutes: 1, seconds: 45),
          duration: const Duration(minutes: 3, seconds: 30),
          isPlaying: true,
          density: ProgressBarDensity.expanded,
          onSeek: (pos) => sought = pos,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('1:45'), findsOneWidget);
    expect(find.text('-1:45'), findsOneWidget);

    await tester.tap(track());
    await tester.pump();
    expect(sought, isNotNull);
  });
}

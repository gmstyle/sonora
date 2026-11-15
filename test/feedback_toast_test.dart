import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/providers/action_feedback_provider.dart';
import 'package:sonora/presentation/shared/widgets/feedback_toast.dart';

void main() {
  testWidgets('sticky error toast takes focus and dismisses on Select', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  autofocus: true,
                  onPressed: () => FeedbackToast.show(
                    context,
                    'Playback failed',
                    kind: FeedbackKind.error,
                  ),
                  child: const Text('Trigger'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();

    expect(find.text('Playback failed'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'feedbackToastClose',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.text('Playback failed'), findsNothing);
  });

  testWidgets('sticky error toast dismisses on Escape', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => FeedbackToast.show(
                    context,
                    'Network error',
                    kind: FeedbackKind.error,
                  ),
                  child: const Text('Trigger'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Trigger'));
    await tester.pumpAndSettle();
    expect(find.text('Network error'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Network error'), findsNothing);
  });
}

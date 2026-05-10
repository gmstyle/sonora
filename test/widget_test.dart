import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/main.dart';
import 'package:sonora/presentation/features/player/audio_handler.dart';
import 'package:sonora/presentation/providers/player_provider.dart';

void main() {
  testWidgets('App shows Hello Sonora', (WidgetTester tester) async {
    final handler = SonoraAudioHandler();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
        ],
        child: const SonoraApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sonora'), findsOneWidget);
    expect(find.text('Hello Sonora'), findsOneWidget);
  });
}

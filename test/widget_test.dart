import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/main.dart';
import 'package:sonora/presentation/features/player/audio_handler.dart';
import 'package:sonora/presentation/providers/database_provider.dart';
import 'package:sonora/presentation/providers/player_provider.dart';

void main() {
  testWidgets('App builds and shows title', (WidgetTester tester) async {
    final handler = SonoraAudioHandler();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
          databaseProvider.overrideWithValue(db),
        ],
        child: const SonoraApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Sonora'), findsAtLeast(1));
  });
}

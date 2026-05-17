import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/data/datasources/local/database.dart';
import 'package:sonora/main.dart';
import 'package:sonora/presentation/features/player/audio_handler.dart';
import 'package:sonora/presentation/providers/database_provider.dart';
import 'package:sonora/presentation/providers/player_provider.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';

void main() {
  testWidgets('App builds and shows title', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final handler = SonoraAudioHandler();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const SonoraApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Sonora'), findsAtLeast(1));
  });
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/settings/settings_screen.dart';
import 'package:sonora/presentation/features/settings/settings_shared.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget app({SettingsCategory? initialCategory}) {
    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(initialCategory: initialCategory),
      ),
    );
  }

  void useSize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
  }

  testWidgets('wide shows the unified header and grouped rail', (tester) async {
    useSize(tester, const Size(1440, 900));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Preferences for this device'), findsOneWidget);
    expect(find.text('Local only'), findsNothing);
    expect(find.text('Look & feel'.toUpperCase()), findsOneWidget);
    expect(find.text('Assistant'.toUpperCase()), findsOneWidget);
    expect(find.text('Data'.toUpperCase()), findsOneWidget);
    expect(find.text('Theme, AMOLED, colors and vinyl style'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet keeps the category when resized to wide', (tester) async {
    useSize(tester, const Size(1024, 768));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Local only'), findsNothing);
    expect(find.text('Privacy'), findsOneWidget);

    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy'), findsNWidgets(2));
    expect(find.text('Track listening history'), findsOneWidget);

    useSize(tester, const Size(1440, 900));
    await tester.pumpAndSettle();

    expect(find.text('Track listening history'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('below 840 falls back to the category list', (tester) async {
    useSize(tester, const Size(800, 900));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Preferences for this device'), findsNothing);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme, AMOLED, colors and vinyl style'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deep link opens the category in the split', (tester) async {
    useSize(tester, const Size(1024, 768));
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(app(initialCategory: SettingsCategory.privacy));
    await tester.pumpAndSettle();

    expect(find.text('Track listening history'), findsOneWidget);
    expect(find.text('Privacy'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}

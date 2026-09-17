import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/presentation/features/library/widgets/import_playlist_dialog.dart';

const _longUrl =
    'https://open.spotify.com/playlist/5PlaEJOgemuwJGdHmCTAxg?si=240a7072fc3e4e58';

void main() {
  group('importPlaylistDialogWidth', () {
    test('compact uses the full screen width', () {
      expect(importPlaylistDialogWidth(390), 390);
      expect(importPlaylistUsesSheet(390), isTrue);
    });

    test('tablet locks at 480dp', () {
      expect(importPlaylistDialogWidth(800), kImportPlaylistDialogTabletWidth);
      expect(importPlaylistUsesSheet(800), isFalse);
    });

    test('wide locks at 560dp', () {
      expect(importPlaylistDialogWidth(1440), kImportPlaylistDialogWideWidth);
      expect(importPlaylistUsesSheet(1440), isFalse);
    });

    test('never exceeds the screen minus insets', () {
      expect(importPlaylistDialogWidth(600), 552);
    });
  });

  group('ImportPlaylistDialog overlay', () {
    testWidgets('compact opens a full-width sheet', (tester) async {
      await _open(tester, const Size(390, 844));

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(
        find.text('Paste a YouTube Music or Spotify playlist link.'),
        findsOneWidget,
      );

      final sheetWidth = tester.getSize(find.byType(BottomSheet)).width;
      expect(sheetWidth, closeTo(390, 0.5));

      await tester.enterText(find.byType(TextField), _longUrl);
      await tester.pump();
      expect(
        tester.getSize(find.byType(BottomSheet)).width,
        closeTo(sheetWidth, 0.5),
      );
    });

    testWidgets('tablet dialog stays 480dp after a long URL', (tester) async {
      await _open(tester, const Size(800, 1280));

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      final emptyWidth = tester.getSize(find.byType(Dialog)).width;
      expect(emptyWidth, closeTo(kImportPlaylistDialogTabletWidth, 1));

      await tester.enterText(find.byType(TextField), _longUrl);
      await tester.pump();
      expect(
        tester.getSize(find.byType(Dialog)).width,
        closeTo(emptyWidth, 0.5),
      );
    });

    testWidgets('wide dialog stays 560dp after a long URL', (tester) async {
      await _open(tester, const Size(1440, 900));

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      final emptyWidth = tester.getSize(find.byType(Dialog)).width;
      expect(emptyWidth, closeTo(kImportPlaylistDialogWideWidth, 1));

      await tester.enterText(find.byType(TextField), _longUrl);
      await tester.pump();
      expect(
        tester.getSize(find.byType(Dialog)).width,
        closeTo(emptyWidth, 0.5),
      );
    });
  });
}

Future<void> _open(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _Host(),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => ImportPlaylistDialog.show(context),
          child: const Text('Open'),
        ),
      ),
    );
  }
}

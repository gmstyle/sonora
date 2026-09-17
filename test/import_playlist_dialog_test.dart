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

    test('600dp is tablet, so it locks at 480 not full width', () {
      expect(importPlaylistDialogWidth(600), kImportPlaylistDialogTabletWidth);
      expect(importPlaylistUsesSheet(600), isFalse);
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

      final emptyWidth = _dialogCardSize(tester).width;
      expect(emptyWidth, closeTo(kImportPlaylistDialogTabletWidth, 1));

      await tester.enterText(find.byType(TextField), _longUrl);
      await tester.pump();
      expect(_dialogCardSize(tester).width, closeTo(emptyWidth, 0.5));
    });

    testWidgets('wide dialog stays 560dp after a long URL', (tester) async {
      await _open(tester, const Size(1440, 900));

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      final emptyWidth = _dialogCardSize(tester).width;
      expect(emptyWidth, closeTo(kImportPlaylistDialogWideWidth, 1));

      await tester.enterText(find.byType(TextField), _longUrl);
      await tester.pump();
      expect(_dialogCardSize(tester).width, closeTo(emptyWidth, 0.5));
    });

    testWidgets('compact sheet stays shrink-wrapped above the keyboard', (
      tester,
    ) async {
      const screen = Size(390, 844);
      const keyboardHeight = 336.0;
      await _open(tester, screen);

      tester.view.physicalSize = Size(
        screen.width,
        screen.height - keyboardHeight,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboardHeight);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Import Playlist'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      final remaining = screen.height - keyboardHeight;
      final sheet = tester.getSize(find.byType(BottomSheet));
      expect(sheet.height, lessThan(remaining * 0.75));

      final field = tester.getRect(find.byType(TextField));
      expect(field.height, greaterThan(40));
      expect(field.top, greaterThanOrEqualTo(0));
      expect(field.bottom, lessThanOrEqualTo(remaining + 0.5));
    });
  });
}

Size _dialogCardSize(WidgetTester tester) {
  return tester.getSize(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.type == MaterialType.card,
      ),
    ),
  );
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

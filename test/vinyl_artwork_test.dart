import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/providers/settings_provider.dart';
import 'package:sonora/presentation/shared/widgets/thumbnail_widget.dart';
import 'package:sonora/presentation/shared/widgets/vinyl_artwork.dart';

class _StillSettings extends SettingsNotifier {
  @override
  Settings build() => const Settings(reduceEffects: true);
}

void main() {
  test('label shrinks toward a 12-inch record as the disc grows', () {
    expect(vinylLabelFraction(44), closeTo(0.64, 0.001));
    expect(vinylLabelFraction(320), closeTo(0.38, 0.001));
    expect(vinylLabelFraction(600), closeTo(0.38, 0.001));
    expect(vinylLabelFraction(180), lessThan(vinylLabelFraction(80)));
  });

  test('tonearm pivot sits off the platter and the needle on the grooves', () {
    const size = 320.0;
    final fraction = vinylLabelFraction(size);
    final anchors = vinylTonearmAnchors(size, fraction);
    final center = const Offset(size / 2, size / 2);
    final radius = size / 2;
    final labelRadius = radius * fraction;

    expect((anchors.pivot - center).distance, greaterThan(radius));
    expect(anchors.pivot.dx, inInclusiveRange(0, size));
    expect(anchors.pivot.dy, inInclusiveRange(0, size));

    final stylusDist = (anchors.stylus - center).distance;
    expect(stylusDist, greaterThan(labelRadius));
    expect(stylusDist, lessThan(radius * 0.98));
  });

  test('spindle stays a pinhole, not a CD hub', () {
    expect(vinylSpindleDiameter(320), closeTo(320 * 0.026, 0.01));
    expect(vinylSpindleDiameter(320), lessThan(320 * (11 / 48)));
    expect(vinylSpindleDiameter(44), 3);
  });

  testWidgets('album art is the center label', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(_StillSettings.new)],
        child: const MaterialApp(
          home: Scaffold(
            body: VinylArtwork(imageUrl: null, size: 320, isPlaying: false),
          ),
        ),
      ),
    );

    final thumb = tester.widget<ThumbnailWidget>(find.byType(ThumbnailWidget));
    expect(thumb.size, closeTo(320 * vinylLabelFraction(320), 0.5));
    expect(thumb.size, lessThan(320 * 0.5));
    expect(find.byType(CustomPaint), findsWidgets);
  });
}

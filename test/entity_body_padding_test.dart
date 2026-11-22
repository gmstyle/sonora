import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/shared/widgets/entity_wide_body.dart';

void main() {
  group('entityBodyPadding', () {
    test('compact adds the shell bottom inset to the 16 base padding', () {
      final padding = entityBodyPadding(
        400,
        bottomInset: 24,
        shellShortestSide: 400,
      );

      expect(padding.bottom, 16 + 24);
    });

    test('wide adds the shell bottom inset to the 48 base padding', () {
      final padding = entityBodyPadding(
        1440,
        bottomInset: 24,
        shellShortestSide: 900,
      );

      expect(padding.bottom, 48 + 24);
    });

    test('defaults to no extra bottom inset', () {
      final padding = entityBodyPadding(400, shellShortestSide: 400);

      expect(padding.bottom, 16);
    });
  });
}

import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/utils/layout_breakpoints.dart';

void main() {
  test('isCompactShell uses shortestSide, not width alone', () {
    // Portrait phone.
    expect(isCompactShell(const Size(390, 844)), isTrue);
    // Landscape phone: width ≥ 600 but short side still under compact.
    expect(isCompactShell(const Size(780, 360)), isTrue);
    // Small tablet / large phone that clears compact on both sides.
    expect(isCompactShell(const Size(800, 600)), isFalse);
  });

  test('isTabletShell and isWideShell exclude compact', () {
    expect(isTabletShell(const Size(780, 360)), isFalse);
    expect(isWideShell(const Size(780, 360)), isFalse);

    expect(isTabletShell(const Size(900, 700)), isTrue);
    expect(isWideShell(const Size(900, 700)), isFalse);

    expect(isTabletShell(const Size(1400, 900)), isFalse);
    expect(isWideShell(const Size(1400, 900)), isTrue);
  });
}

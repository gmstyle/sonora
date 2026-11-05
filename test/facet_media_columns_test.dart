import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/shared/widgets/facet_wide_scaffold.dart';

void main() {
  test('facetMediaColumnCount scales with the results column', () {
    expect(facetMediaColumnCount(0), 2);
    expect(facetMediaColumnCount(-20), 2);
    expect(facetMediaColumnCount(double.nan), 2);
    expect(facetMediaColumnCount(double.infinity), 2);
    expect(facetMediaColumnCount(400), 2);
    expect(facetMediaColumnCount(700), 3);
    expect(facetMediaColumnCount(1000), 4);
    expect(facetMediaColumnCount(1200), 5);
    expect(facetMediaColumnCount(2400), 5);
  });
}

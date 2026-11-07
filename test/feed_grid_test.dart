import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/constants/app_constants.dart';
import 'package:sonora/core/utils/feed_grid.dart';

void main() {
  test('feedGridColumnCount steps at 600, 800, 1600, and 1920', () {
    expect(feedGridColumnCount(599), 2);
    expect(feedGridColumnCount(600), 3);
    expect(feedGridColumnCount(799), 3);
    expect(feedGridColumnCount(800), 4);
    expect(feedGridColumnCount(1599), 4);
    expect(feedGridColumnCount(1600), 5);
    expect(feedGridColumnCount(1919), 5);
    expect(feedGridColumnCount(1920), 6);
  });

  test('feedHorizontalPadding is 16, 24, then 32', () {
    expect(feedHorizontalPadding(599), 16);
    expect(feedHorizontalPadding(600), kTabletContentPadding);
    expect(feedHorizontalPadding(1199), kTabletContentPadding);
    expect(feedHorizontalPadding(1200), kWideContentPadding);
    expect(kTabletContentPadding, 24);
    expect(kWideContentPadding, 32);
  });
}

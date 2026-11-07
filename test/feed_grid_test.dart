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
    expect(feedHorizontalPadding(599), kCompactContentPadding);
    expect(feedHorizontalPadding(600), kTabletContentPadding);
    expect(feedHorizontalPadding(1199), kTabletContentPadding);
    expect(feedHorizontalPadding(1200), kWideContentPadding);
    expect(kCompactContentPadding, 16);
    expect(kTabletContentPadding, 24);
    expect(kWideContentPadding, 32);
  });

  test('compact shell forces 2 columns and pad 16 on wide content', () {
    // Landscape phone: content box ~780, shortestSide 360 → still mobile.
    expect(feedGridColumnCount(780, shellShortestSide: 360), 2);
    expect(
      feedHorizontalPadding(780, shellShortestSide: 360),
      kCompactContentPadding,
    );

    final spec = FeedGridSpec.fromWidth(780, shellShortestSide: 360);
    expect(spec.columns, 2);
    expect(spec.horizontalPadding, kCompactContentPadding);
  });

  test('without shellShortestSide, wide content stays tablet columns', () {
    expect(feedGridColumnCount(780), 3);
    expect(feedHorizontalPadding(780), kTabletContentPadding);

    final spec = FeedGridSpec.fromWidth(780);
    expect(spec.columns, 3);
    expect(spec.horizontalPadding, kTabletContentPadding);
  });
}

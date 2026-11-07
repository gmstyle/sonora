import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/constants/app_constants.dart';
import 'package:sonora/presentation/features/player/layouts/wide_player_layout.dart';
import 'package:sonora/presentation/providers/player_provider.dart';

void main() {
  test('wide player drawer is narrower below 1600', () {
    final frame = widePlayerFrame(1280);

    expect(frame.queue, 320);
    expect(frame.insights, 480);
    expect(frame.artMax, 420);
  });

  test('wide player drawer grows at 1600', () {
    final frame = widePlayerFrame(kWideContentBreakpoint);

    expect(frame.queue, 380);
    expect(frame.insights, 560);
    expect(frame.artMax, 520);
  });

  test('queue drawer stays open beside lyrics', () {
    expect(wideQueueOpen(drawer: true, view: PlayerSubView.lyrics), isTrue);
    expect(wideCanvasView(PlayerSubView.lyrics), PlayerSubView.lyrics);
  });

  test(
    'a queue subview opens the drawer and leaves the canvas on the disc',
    () {
      expect(wideQueueOpen(drawer: false, view: PlayerSubView.queue), isTrue);
      expect(wideCanvasView(PlayerSubView.queue), PlayerSubView.none);
    },
  );

  test('related stays on the scroll instead of replacing it', () {
    expect(wideCanvasView(PlayerSubView.related), PlayerSubView.none);
  });

  test('tablet curiosities drawer stays within half the window', () {
    final narrow = tabletPlayerFrame(768);

    expect(narrow.queue, 300);
    expect(narrow.insights, 384);
    expect(narrow.artMax, 340);

    final roomy = tabletPlayerFrame(1100);

    expect(roomy.queue, 300);
    expect(roomy.insights, 420);
    expect(roomy.artMax, 400);
  });
}

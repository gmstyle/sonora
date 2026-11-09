import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/theme/sonora_pulse_tokens.dart';
import 'package:sonora/presentation/features/home/layouts/home_layout_metrics.dart';
import 'package:sonora/presentation/features/home/widgets/home_section_renderer.dart';
import 'package:sonora/presentation/shared/widgets/collection_shimmer.dart';
import 'package:sonora/presentation/shared/widgets/entity_shimmer.dart';
import 'package:sonora/presentation/shared/widgets/shimmer_loading.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pump();
  }

  testWidgets('card cover uses the media radius', (tester) async {
    await pump(
      tester,
      const ShimmerLoading(variant: ShimmerVariant.card, cardWidth: 160),
      const Size(800, 600),
    );
    final covers = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((box) {
          final decoration = box.decoration as BoxDecoration;
          return decoration.borderRadius ==
              BorderRadius.circular(SonoraPulseTokens.radiusMedia);
        });
    expect(covers, hasLength(1));
  });

  testWidgets('compact entity skeleton centers a 140 cover', (tester) async {
    await pump(
      tester,
      const EntityShimmer(kind: EntityShimmerKind.tracks, contentWidth: 400),
      const Size(400, 800),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('entity-shimmer-art'))),
      const Size(140, 140),
    );
    expect(find.byKey(const Key('entity-shimmer-actions')), findsOneWidget);
  });

  testWidgets('wide entity skeleton uses the 180 cover', (tester) async {
    await pump(
      tester,
      const EntityShimmer(kind: EntityShimmerKind.tracks, contentWidth: 1280),
      const Size(1400, 900),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('entity-shimmer-art'))),
      const Size(180, 180),
    );
  });

  testWidgets('artist skeleton fills the photo header', (tester) async {
    await pump(
      tester,
      const EntityShimmer(kind: EntityShimmerKind.artist, contentWidth: 400),
      const Size(400, 800),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('entity-shimmer-art'))).width,
      greaterThan(300),
    );
    expect(find.byKey(const Key('entity-shimmer-actions')), findsOneWidget);
  });

  testWidgets('profile skeleton is a circle and has no actions', (
    tester,
  ) async {
    await pump(
      tester,
      const EntityShimmer(kind: EntityShimmerKind.profile, contentWidth: 900),
      const Size(900, 1200),
    );
    expect(tester.takeException(), isNull);
    final art = find.byKey(const Key('entity-shimmer-art'));
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: art, matching: find.byType(DecoratedBox)),
    );
    expect((box.decoration as BoxDecoration).shape, BoxShape.circle);
    expect(find.byKey(const Key('entity-shimmer-actions')), findsNothing);
  });

  testWidgets('library loading follows the grid switch', (tester) async {
    await pump(
      tester,
      const LibraryCollectionShimmer(grid: false),
      const Size(400, 800),
    );
    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsOneWidget);

    await pump(
      tester,
      const LibraryCollectionShimmer(grid: true),
      const Size(400, 800),
    );
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
  });

  testWidgets('wide search loading uses the facet column count', (
    tester,
  ) async {
    await pump(tester, const SearchShelfShimmer(), const Size(1280, 800));
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 5);
    expect(grid.childrenDelegate.estimatedChildCount, 10);
  });

  testWidgets('mini player skeleton matches the slot', (tester) async {
    await pump(
      tester,
      const Center(
        child: SizedBox(
          width: 360,
          height: 60,
          child: ShimmerLoading(variant: ShimmerVariant.miniPlayer),
        ),
      ),
      const Size(400, 800),
    );
    expect(find.byKey(const Key('mini-player-row')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('mini-player-art'))).width, 44);

    await pump(
      tester,
      const Center(
        child: SizedBox(
          width: 1200,
          height: 80,
          child: ShimmerLoading(variant: ShimmerVariant.miniPlayer),
        ),
      ),
      const Size(1400, 900),
    );
    expect(find.byKey(const Key('mini-player-shelf')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('mini-player-art'))).width, 56);
  });

  testWidgets('song tile skeleton matches the list row', (tester) async {
    await pump(
      tester,
      const ShimmerLoading(variant: ShimmerVariant.tile),
      const Size(400, 200),
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.height == 72,
      ),
      findsOneWidget,
    );
    final art = find.byWidgetPredicate(
      (widget) =>
          widget is SizedBox && widget.width == 48 && widget.height == 48,
    );
    expect(art, findsOneWidget);
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: art, matching: find.byType(DecoratedBox)),
    );
    expect(
      (box.decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(SonoraPulseTokens.radiusSm),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.width == 36 && widget.height == 12,
      ),
      findsOneWidget,
    );
  });

  testWidgets('queue skeleton uses the 68px row', (tester) async {
    await pump(
      tester,
      const ShimmerLoading(variant: ShimmerVariant.queue),
      const Size(400, 800),
    );
    expect(tester.takeException(), isNull);
    final tiles = find.byWidgetPredicate(
      (widget) => widget is SizedBox && widget.height == 68,
    );
    expect(tiles, findsNWidgets(5));
    final art = find.descendant(
      of: tiles.first,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.width == 48 && widget.height == 48,
      ),
    );
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: art, matching: find.byType(DecoratedBox)),
    );
    expect(
      (box.decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(4),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox && widget.height == 48 && widget.width == null,
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('wide resume row is padded once', (tester) async {
    await pump(
      tester,
      const ShimmerLoading(
        variant: ShimmerVariant.homeQuickRow,
        sideBySideQuickRow: true,
        horizontalPadding: 32,
      ),
      const Size(1280, 900),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(find.byKey(const Key('home-quick-row'))).dx, 32);
  });

  testWidgets('home loading follows the feed order', (tester) async {
    await pump(
      tester,
      const HomeShimmer(
        metrics: HomeLayoutMetrics(HomeLayoutSize.mobile, contentWidth: 400),
      ),
      const Size(400, 6000),
    );
    expect(tester.takeException(), isNull);
    final quick = tester
        .getTopLeft(find.byKey(const Key('home-shimmer-quick')))
        .dy;
    final explore = tester
        .getTopLeft(find.byKey(const Key('home-shimmer-explore')))
        .dy;
    final music = tester
        .getTopLeft(find.byKey(const Key('home-shimmer-music')))
        .dy;
    final hero = tester
        .getTopLeft(find.byKey(const Key('home-shimmer-hero')))
        .dy;
    expect(quick, lessThan(explore));
    expect(explore, lessThan(music));
    expect(music, lessThan(hero));
    expect(find.byType(Wrap), findsNothing);
  });

  testWidgets('mood loading wraps chips', (tester) async {
    await pump(
      tester,
      const ShimmerLoading(variant: ShimmerVariant.moodSection),
      const Size(400, 400),
    );
    expect(find.byType(Wrap), findsOneWidget);
  });
}

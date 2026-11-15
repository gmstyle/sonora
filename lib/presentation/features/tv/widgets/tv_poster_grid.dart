import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../tv_metrics.dart';

/// Lazy grid of fixed-size [TvPosterCard]-shaped cells.
///
/// Matches home/entity shelf posters: cards stay at [TvMetrics.shelfCardWidth]
/// × [TvMetrics.posterCardHeight] and are not stretched by aspect-ratio grids.
class TvPosterGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics? physics;

  const TvPosterGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(TvMetrics.contentPadding),
    this.physics,
  });

  /// Cross-axis count for a content pane of [width].
  static int crossAxisCountFor(double width) {
    return math.max(
      1,
      (width + TvMetrics.posterGridGap) ~/
          (TvMetrics.shelfCardWidth + TvMetrics.posterGridGap),
    );
  }

  /// Shared delegate so Sliver grids match [GridView] layouts.
  static SliverGridDelegate delegateFor(double width) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCountFor(width),
      mainAxisExtent: TvMetrics.posterCardHeight,
      crossAxisSpacing: TvMetrics.posterGridGap,
      mainAxisSpacing: TvMetrics.posterGridGap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          padding: padding,
          physics: physics,
          gridDelegate: delegateFor(constraints.maxWidth),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return Align(
              alignment: Alignment.topLeft,
              child: itemBuilder(context, index),
            );
          },
        );
      },
    );
  }
}

/// Sliver counterpart of [TvPosterGrid] for [CustomScrollView] hosts.
class TvPosterSliverGrid extends StatelessWidget {
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;

  const TvPosterSliverGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(
      horizontal: TvMetrics.contentPadding,
      vertical: 8,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          return SliverGrid(
            gridDelegate: TvPosterGrid.delegateFor(constraints.crossAxisExtent),
            delegate: SliverChildBuilderDelegate((context, index) {
              return Align(
                alignment: Alignment.topLeft,
                child: itemBuilder(context, index),
              );
            }, childCount: itemCount),
          );
        },
      ),
    );
  }
}

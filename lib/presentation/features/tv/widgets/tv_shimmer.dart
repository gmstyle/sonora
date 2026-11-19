import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/shimmer_loading.dart';
import '../tv_metrics.dart';
import 'tv_poster_grid.dart';

/// Skeleton for [TvHomeScreen] matching the 10-foot browser anatomy:
/// featured 16:9 row → category pill row → catalog poster shelves.
class TvHomeShimmer extends StatelessWidget {
  const TvHomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading.wrap(
      context,
      child: const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: TvMetrics.browseTopPadding, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TvSectionHeaderBone(width: 140),
            _TvFeaturedRowBones(),
            SizedBox(height: TvMetrics.shelfGap),
            _TvSectionHeaderBone(width: 160),
            _TvCategoryRowBones(),
            SizedBox(height: TvMetrics.shelfGap),
            _TvShelfBlockBones(),
            _TvShelfBlockBones(),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for one or more horizontal poster shelves on Android TV.
class TvShelfShimmer extends StatelessWidget {
  final int count;

  const TvShelfShimmer({super.key, this.count = 1});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading.wrap(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (var i = 0; i < count; i++) const _TvShelfBlockBones()],
      ),
    );
  }
}

/// Skeleton matching [TvPosterGrid] and [TvPosterSliverGrid] column math and padding.
class TvPosterGridShimmer extends StatelessWidget {
  final bool circle;
  final bool shrinkWrap;
  final EdgeInsetsGeometry padding;
  final int itemCount;

  const TvPosterGridShimmer({
    super.key,
    this.circle = false,
    this.shrinkWrap = false,
    this.padding = const EdgeInsets.all(TvMetrics.contentPadding),
    this.itemCount = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading.wrap(
      context,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final resolvedPadding = padding.resolve(Directionality.of(context));
          final contentWidth =
              constraints.maxWidth - resolvedPadding.horizontal;
          return GridView.builder(
            shrinkWrap: shrinkWrap,
            physics: const NeverScrollableScrollPhysics(),
            padding: padding,
            gridDelegate: TvPosterGrid.delegateFor(contentWidth),
            itemCount: itemCount,
            itemBuilder: (_, _) => Align(
              alignment: Alignment.topLeft,
              child: _TvPosterCardBone(circle: circle),
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton matching the 40/60 two-pane Android TV entity screens
/// (left [TvEntitySideColumn] + right track/episode rows).
class TvEntityShimmer extends StatelessWidget {
  final bool circleArtwork;
  final int rowCount;

  const TvEntityShimmer({
    super.key,
    this.circleArtwork = false,
    this.rowCount = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TvColors.bg,
      body: SafeArea(
        child: ShimmerLoading.wrap(
          context,
          child: Padding(
            padding: const EdgeInsets.all(TvMetrics.contentPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      _TvBone(
                        width: 180,
                        height: 180,
                        radius: circleArtwork ? 90 : TvMetrics.cardRadius,
                      ),
                      const SizedBox(height: 18),
                      const _TvBone(width: 210, height: 20, radius: 6),
                      const SizedBox(height: 8),
                      const _TvBone(width: 140, height: 14, radius: 5),
                      const SizedBox(height: 20),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TvBone(width: 96, height: 40, radius: 20),
                          SizedBox(width: 10),
                          _TvBone(width: 96, height: 40, radius: 20),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const _TvBone(width: 120, height: 36, radius: 18),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rowCount,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, _) => const _TvTrackRowBone(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TvSectionHeaderBone extends StatelessWidget {
  final double width;

  const _TvSectionHeaderBone({required this.width});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: TvMetrics.contentPadding,
        right: TvMetrics.contentPadding,
        bottom: TvMetrics.shelfTitleGap,
      ),
      child: Row(
        children: [
          const _TvBone(width: 5, height: 15, radius: 99),
          const SizedBox(width: 10),
          _TvBone(width: width, height: 14, radius: 4),
        ],
      ),
    );
  }
}

class _TvFeaturedRowBones extends StatelessWidget {
  const _TvFeaturedRowBones();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TvMetrics.featuredCardHeight,
      child: ListView.separated(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: TvMetrics.contentPadding,
        ),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (_, _) => Container(
          width: TvMetrics.featuredCardWidth,
          height: TvMetrics.featuredCardHeight,
          padding: const EdgeInsets.all(TvMetrics.shelfCardPadding),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(TvMetrics.cardRadius),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TvBone(
                width: double.infinity,
                height: TvMetrics.featuredCardImageHeight,
                radius: 8,
              ),
              SizedBox(height: 10),
              _TvBone(width: 148, height: 13, radius: 4),
              SizedBox(height: 6),
              _TvBone(width: 96, height: 10, radius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvCategoryRowBones extends StatelessWidget {
  const _TvCategoryRowBones();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TvMetrics.categoryCardHeight,
      child: ListView.separated(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: TvMetrics.contentPadding,
        ),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Container(
          width: TvMetrics.categoryCardWidth,
          height: TvMetrics.categoryCardHeight,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _TvShelfBlockBones extends StatelessWidget {
  const _TvShelfBlockBones();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TvMetrics.shelfGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TvSectionHeaderBone(width: 160),
          SizedBox(
            height: TvMetrics.posterCardHeight,
            child: ListView.separated(
              primary: false,
              physics: const NeverScrollableScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: TvMetrics.contentPadding,
              ),
              itemCount: 6,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (_, _) => const _TvPosterCardBone(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TvPosterCardBone extends StatelessWidget {
  final bool circle;

  const _TvPosterCardBone({this.circle = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: TvMetrics.shelfCardWidth,
      height: TvMetrics.posterCardHeight,
      padding: const EdgeInsets.all(TvMetrics.shelfCardPadding),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(TvMetrics.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: circle
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          _TvBone(
            width: TvMetrics.shelfCardImageSize,
            height: TvMetrics.shelfCardImageSize,
            radius: circle ? TvMetrics.shelfCardImageSize / 2 : 8,
          ),
          const SizedBox(height: 8),
          _TvBone(width: circle ? 88 : 104, height: 12, radius: 4),
          const SizedBox(height: 5),
          if (!circle) const _TvBone(width: 72, height: 10, radius: 4),
        ],
      ),
    );
  }
}

class _TvTrackRowBone extends StatelessWidget {
  const _TvTrackRowBone();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(TvMetrics.cardRadius),
      ),
      child: const Row(
        children: [
          _TvBone(width: 44, height: 44, radius: 8),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TvBone(width: 220, height: 14, radius: 4),
                SizedBox(height: 6),
                _TvBone(width: 140, height: 11, radius: 4),
              ],
            ),
          ),
          SizedBox(width: 16),
          _TvBone(width: 36, height: 12, radius: 4),
        ],
      ),
    );
  }
}

class _TvBone extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _TvBone({required this.width, required this.height, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

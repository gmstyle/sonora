import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

enum ShimmerVariant { card, tile, carousel }

class ShimmerLoading extends StatelessWidget {
  final ShimmerVariant variant;

  const ShimmerLoading({super.key, this.variant = ShimmerVariant.card});

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlightColor = Theme.of(context).colorScheme.surfaceContainerLow;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: switch (variant) {
        ShimmerVariant.card => _ShimmerCard(),
        ShimmerVariant.tile => _ShimmerTile(),
        ShimmerVariant.carousel => _ShimmerCarousel(),
      },
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 160, height: 160, child: ColoredBox(color: Colors.white)),
        SizedBox(height: 8),
        SizedBox(width: 120, height: 12, child: ColoredBox(color: Colors.white)),
        SizedBox(height: 4),
        SizedBox(width: 80, height: 10, child: ColoredBox(color: Colors.white)),
      ],
    );
  }
}

class _ShimmerTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 48, height: 48, child: ColoredBox(color: Colors.white)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 14, width: double.infinity, child: ColoredBox(color: Colors.white)),
                SizedBox(height: 4),
                SizedBox(height: 12, width: 100, child: ColoredBox(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerCarousel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _ShimmerCard(),
        ),
      ),
    );
  }
}

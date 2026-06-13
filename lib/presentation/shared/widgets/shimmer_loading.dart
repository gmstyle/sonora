import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

enum ShimmerVariant {
  card,
  tile,
  carousel,
  miniPlayer,
  artworkLarge,
  chipsBar,
  section,
}

class ShimmerLoading extends StatelessWidget {
  final ShimmerVariant variant;

  const ShimmerLoading({super.key, this.variant = ShimmerVariant.card});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // On dark themes the highlight must be lighter than the base; on light
    // themes it must be lighter still.  Using fixed opacity steps on white/black
    // guarantees visible contrast regardless of the accent palette.
    final baseColor =
        isDark
            ? const Color(0xFF2C2C2E) // dark: mid-grey base
            : const Color(0xFFE0E0E0); // light: light-grey base
    final highlightColor =
        isDark
            ? const Color(0xFF48484A) // dark: noticeably lighter sweep
            : const Color(0xFFF5F5F5); // light: near-white sweep

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: switch (variant) {
        ShimmerVariant.card => _ShimmerCard(),
        ShimmerVariant.tile => _ShimmerTile(),
        ShimmerVariant.carousel => _ShimmerCarousel(),
        ShimmerVariant.miniPlayer => _ShimmerMiniPlayer(),
        ShimmerVariant.artworkLarge => _ShimmerArtworkLarge(),
        ShimmerVariant.chipsBar => _ShimmerChipsBar(),
        ShimmerVariant.section => const _ShimmerSection(),
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
        SizedBox(
          width: 160,
          height: 160,
          child: ColoredBox(color: Colors.white),
        ),
        SizedBox(height: 8),
        SizedBox(
          width: 120,
          height: 12,
          child: ColoredBox(color: Colors.white),
        ),
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
          SizedBox(
            width: 48,
            height: 48,
            child: ColoredBox(color: Colors.white),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 14,
                  width: double.infinity,
                  child: ColoredBox(color: Colors.white),
                ),
                SizedBox(height: 4),
                SizedBox(
                  height: 12,
                  width: 100,
                  child: ColoredBox(color: Colors.white),
                ),
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
        itemBuilder:
            (_, _) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _ShimmerCard(),
            ),
      ),
    );
  }
}

/// Skeleton that mirrors the exact layout of the mini player row:
/// 12px padding | 48×48 artwork | 12px gap | title + artist bars | play+skip placeholders | 4px padding
class _ShimmerMiniPlayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 12),
          SizedBox(
            width: 48,
            height: 48,
            child: ColoredBox(color: Colors.white),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 14,
                  width: double.infinity,
                  child: ColoredBox(color: Colors.white),
                ),
                SizedBox(height: 4),
                SizedBox(
                  height: 12,
                  width: 120,
                  child: ColoredBox(color: Colors.white),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Large square placeholder for full-player artwork.
class _ShimmerArtworkLarge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: ColoredBox(color: Colors.white),
    );
  }
}

class _ShimmerChipsBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 6,
        itemBuilder:
            (_, _) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                width: 80,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
      ),
    );
  }
}

class _ShimmerSection extends StatelessWidget {
  const _ShimmerSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 150,
                height: 16,
                child: ColoredBox(color: Colors.white),
              ),
              SizedBox(
                width: 60,
                height: 12,
                child: ColoredBox(color: Colors.white),
              ),
            ],
          ),
        ),
        SizedBox(height: 220, child: _ShimmerCardRow()),
      ],
    );
  }
}

class _ShimmerCardRow extends StatelessWidget {
  const _ShimmerCardRow();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder:
          (_, _) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _ShimmerCard(),
          ),
    );
  }
}

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
  zoneHeader,
  homeQuickRow,
  hero,
  exploreChips,

  /// Mimics the layout of the playback queue sheet (header + 2 rows
  /// per section). Used while the queue is being restored on startup.
  queue,
}

class ShimmerLoading extends StatelessWidget {
  final ShimmerVariant variant;
  final double cardWidth;
  final double horizontalPadding;
  final double heroHeight;
  final bool sideBySideQuickRow;
  final double zoneHeaderTop;
  final double zoneHeaderBottom;
  final double zoneGap;

  const ShimmerLoading({
    super.key,
    this.variant = ShimmerVariant.card,
    this.cardWidth = 160,
    this.horizontalPadding = 16,
    this.heroHeight = 180,
    this.sideBySideQuickRow = false,
    this.zoneHeaderTop = 20,
    this.zoneHeaderBottom = 8,
    this.zoneGap = 16,
  });

  double get _sectionShelfHeight => cardWidth + 56;

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
        ShimmerVariant.card => _ShimmerCard(cardWidth: cardWidth),
        ShimmerVariant.tile => _ShimmerTile(
          horizontalPadding: horizontalPadding,
        ),
        ShimmerVariant.carousel => _ShimmerCarousel(cardWidth: cardWidth),
        ShimmerVariant.miniPlayer => _ShimmerMiniPlayer(),
        ShimmerVariant.artworkLarge => _ShimmerArtworkLarge(),
        ShimmerVariant.chipsBar => _ShimmerChipsBar(
          horizontalPadding: horizontalPadding,
        ),
        ShimmerVariant.section => _ShimmerSection(
          cardWidth: cardWidth,
          horizontalPadding: horizontalPadding,
          shelfHeight: _sectionShelfHeight,
        ),
        ShimmerVariant.zoneHeader => _ShimmerZoneHeader(
          horizontalPadding: horizontalPadding,
          topPadding: zoneHeaderTop,
          bottomPadding: zoneHeaderBottom,
        ),
        ShimmerVariant.homeQuickRow => _ShimmerHomeQuickRow(
          horizontalPadding: horizontalPadding,
          sideBySide: sideBySideQuickRow,
          zoneGap: zoneGap,
        ),
        ShimmerVariant.hero => _ShimmerHero(
          horizontalPadding: horizontalPadding,
          heroHeight: heroHeight,
        ),
        ShimmerVariant.exploreChips => _ShimmerExploreChips(
          horizontalPadding: horizontalPadding,
        ),
        ShimmerVariant.queue => const _ShimmerQueue(),
      },
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double cardWidth;

  const _ShimmerCard({this.cardWidth = 160});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: cardWidth,
          height: cardWidth,
          child: const ColoredBox(color: Colors.white),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: cardWidth * 0.75,
          height: 12,
          child: const ColoredBox(color: Colors.white),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: cardWidth * 0.5,
          height: 10,
          child: const ColoredBox(color: Colors.white),
        ),
      ],
    );
  }
}

class _ShimmerTile extends StatelessWidget {
  final double horizontalPadding;

  const _ShimmerTile({this.horizontalPadding = 16});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      child: const Row(
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
  final double cardWidth;

  const _ShimmerCarousel({this.cardWidth = 160});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardWidth + 24,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder:
            (_, _) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _ShimmerCard(cardWidth: cardWidth),
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
  final double horizontalPadding;

  const _ShimmerChipsBar({this.horizontalPadding = 16});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 8,
        ),
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

class _ShimmerZoneHeader extends StatelessWidget {
  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;

  const _ShimmerZoneHeader({
    this.horizontalPadding = 16,
    this.topPadding = 20,
    this.bottomPadding = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            bottomPadding,
          ),
          child: const SizedBox(
            width: 140,
            height: 22,
            child: ColoredBox(color: Colors.white),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: const SizedBox(
            height: 1,
            child: ColoredBox(color: Colors.white),
          ),
        ),
        SizedBox(height: bottomPadding),
      ],
    );
  }
}

class _ShimmerHomeQuickRow extends StatelessWidget {
  final double horizontalPadding;
  final bool sideBySide;
  final double zoneGap;

  const _ShimmerHomeQuickRow({
    this.horizontalPadding = 16,
    this.sideBySide = false,
    this.zoneGap = 16,
  });

  @override
  Widget build(BuildContext context) {
    final continueBlock = _continueBlock(showHeader: !sideBySide);
    final mixesBlock = _mixesBlock(showHeader: !sideBySide);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: sideBySide ? horizontalPadding : 0,
        vertical: zoneGap / 2,
      ),
      child:
          sideBySide
              ? Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 55, child: continueBlock),
                    SizedBox(width: zoneGap),
                    Expanded(flex: 45, child: mixesBlock),
                  ],
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  continueBlock,
                  SizedBox(height: zoneGap),
                  mixesBlock,
                ],
              ),
    );
  }

  Widget _continueBlock({required bool showHeader}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          const SizedBox(
            width: 120,
            height: 16,
            child: ColoredBox(color: Colors.white),
          ),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ShimmerTile(horizontalPadding: sideBySide ? 0 : horizontalPadding),
        ],
      ],
    );
  }

  Widget _mixesBlock({required bool showHeader}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          const SizedBox(
            width: 100,
            height: 16,
            child: ColoredBox(color: Colors.white),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              const Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ColoredBox(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ShimmerHero extends StatelessWidget {
  final double horizontalPadding;
  final double heroHeight;

  const _ShimmerHero({this.horizontalPadding = 16, this.heroHeight = 180});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 8),
      child: SizedBox(
        height: heroHeight,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
    );
  }
}

class _ShimmerExploreChips extends StatelessWidget {
  final double horizontalPadding;

  const _ShimmerExploreChips({this.horizontalPadding = 16});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 80,
            height: 16,
            child: ColoredBox(color: Colors.white),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder:
                  (_, _) => Container(
                    width: 110,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerSection extends StatelessWidget {
  final double cardWidth;
  final double horizontalPadding;
  final double shelfHeight;

  const _ShimmerSection({
    this.cardWidth = 160,
    this.horizontalPadding = 16,
    this.shelfHeight = 216,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            8,
          ),
          child: const Row(
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
        SizedBox(
          height: shelfHeight,
          child: _ShimmerCardRow(
            cardWidth: cardWidth,
            horizontalPadding: horizontalPadding,
          ),
        ),
      ],
    );
  }
}

// ── Queue skeleton ───────────────────────────────────────────────────────

class _ShimmerQueue extends StatelessWidget {
  const _ShimmerQueue();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: const [
        _ShimmerHeader(),
        _ShimmerQueueTile(),
        _ShimmerQueueTile(),
        _ShimmerQueueTile(),
        SizedBox(height: 16),
        _ShimmerHeader(),
        _ShimmerQueueTile(),
        _ShimmerQueueTile(),
      ],
    );
  }
}

class _ShimmerHeader extends StatelessWidget {
  const _ShimmerHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: ColoredBox(color: Colors.white),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 100,
            height: 12,
            child: ColoredBox(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _ShimmerQueueTile extends StatelessWidget {
  const _ShimmerQueueTile();

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
                SizedBox(height: 6),
                SizedBox(
                  height: 12,
                  width: 140,
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

class _ShimmerCardRow extends StatelessWidget {
  final double cardWidth;
  final double horizontalPadding;

  const _ShimmerCardRow({this.cardWidth = 160, this.horizontalPadding = 16});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      itemCount: 5,
      itemBuilder:
          (_, _) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _ShimmerCard(cardWidth: cardWidth),
          ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/sonora_pulse_tokens.dart';
import '../../../core/utils/layout_breakpoints.dart';

enum ShimmerVariant {
  card,
  videoCard,
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

  /// One mood-category block: a title and a wrap of chips.
  moodSection,

  /// Title row used above an explore grid. No divider, no action.
  shelfHeader,

  /// Circle avatars with a name, as on the home artist shelves.
  artistShelf,

  /// Liked-albums grid: same columns and card as the wide shelf.
  mediaGrid,

  /// 16:9 video row used under New releases.
  videoCarousel,

  /// Mimics the layout of the playback queue sheet (header + rows
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
  final double avatarSize;
  final int gridColumns;
  final int gridItemCount;
  final double gridSpacing;
  final double sectionHeaderTop;
  final double sectionHeaderBottom;
  final double viewportFraction;
  final bool showHeader;
  final bool showZoneDivider;

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
    this.avatarSize = 64,
    this.gridColumns = 4,
    this.gridItemCount = 8,
    this.gridSpacing = 12,
    this.sectionHeaderTop = 12,
    this.sectionHeaderBottom = 6,
    this.viewportFraction = 1,
    this.showHeader = false,
    this.showZoneDivider = true,
  });

  /// Space below the square cover for title + subtitle bars.
  /// Matches album/playlist shelf cards ([HomeLayoutMetrics.shelfTextHeight]).
  static const double cardTextHeight = 56;

  double get _sectionShelfHeight => cardWidth + cardTextHeight;

  /// One shimmer pass. Entity and collection skeletons share these colours.
  static Widget wrap(BuildContext context, {required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final baseColor = isDark
        ? scheme.surfaceContainer
        : scheme.surfaceContainerHigh;
    final highlightColor = isDark
        ? scheme.surfaceContainerHighest
        : scheme.surfaceContainerLowest;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return wrap(
      context,
      child: switch (variant) {
        ShimmerVariant.card => _ShimmerCard(cardWidth: cardWidth),
        ShimmerVariant.videoCard => _ShimmerVideoCard(cardWidth: cardWidth),
        ShimmerVariant.tile => _ShimmerTile(
          horizontalPadding: horizontalPadding,
        ),
        ShimmerVariant.carousel => _ShimmerCarousel(
          cardWidth: cardWidth,
          horizontalPadding: horizontalPadding,
          itemGap: 12,
        ),
        ShimmerVariant.videoCarousel => _ShimmerCarousel(
          cardWidth: cardWidth,
          horizontalPadding: horizontalPadding,
          itemGap: 12,
          video: true,
        ),
        ShimmerVariant.miniPlayer => _ShimmerMiniPlayer(),
        ShimmerVariant.artworkLarge => _ShimmerArtworkLarge(),
        ShimmerVariant.chipsBar => _ShimmerChipsBar(
          horizontalPadding: horizontalPadding,
        ),
        ShimmerVariant.section => _ShimmerSection(
          cardWidth: cardWidth,
          horizontalPadding: horizontalPadding,
          shelfHeight: _sectionShelfHeight,
          headerTop: sectionHeaderTop,
          headerBottom: sectionHeaderBottom,
        ),
        ShimmerVariant.zoneHeader => _ShimmerZoneHeader(
          horizontalPadding: horizontalPadding,
          topPadding: zoneHeaderTop,
          bottomPadding: zoneHeaderBottom,
          showDivider: showZoneDivider,
        ),
        ShimmerVariant.shelfHeader => _ShimmerShelfHeader(
          horizontalPadding: horizontalPadding,
          top: sectionHeaderTop,
          bottom: sectionHeaderBottom,
          showAction: false,
        ),
        ShimmerVariant.artistShelf => _ShimmerArtistShelf(
          horizontalPadding: horizontalPadding,
          avatarSize: avatarSize,
          headerTop: sectionHeaderTop,
          headerBottom: sectionHeaderBottom,
        ),
        ShimmerVariant.mediaGrid => _ShimmerMediaGrid(
          cardWidth: cardWidth,
          horizontalPadding: horizontalPadding,
          columns: gridColumns,
          itemCount: gridItemCount,
          spacing: gridSpacing,
          headerTop: sectionHeaderTop,
          headerBottom: sectionHeaderBottom,
        ),
        ShimmerVariant.homeQuickRow => _ShimmerHomeQuickRow(
          horizontalPadding: horizontalPadding,
          sideBySide: sideBySideQuickRow,
          zoneGap: zoneGap,
        ),
        ShimmerVariant.hero => _ShimmerHero(
          horizontalPadding: horizontalPadding,
          heroHeight: heroHeight,
          viewportFraction: viewportFraction,
          showHeader: showHeader,
          headerTop: sectionHeaderTop,
          headerBottom: sectionHeaderBottom,
        ),
        ShimmerVariant.exploreChips => _ShimmerExploreChips(
          horizontalPadding: horizontalPadding,
        ),
        ShimmerVariant.moodSection => _ShimmerMoodSection(
          horizontalPadding: horizontalPadding,
        ),
        ShimmerVariant.queue => const _ShimmerQueue(),
      },
    );
  }
}

/// Text and chip bones. 4 matches a glyph; pills use [SonoraPulseTokens.radiusPill].
const double _kTextBoneRadius = 4;

class _Bone extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _Bone({
    required this.width,
    required this.height,
    this.radius = _kTextBoneRadius,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Square or 16:9 cover. Radius matches shelf cards.
class _ShimmerCover extends StatelessWidget {
  const _ShimmerCover();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(
          Radius.circular(SonoraPulseTokens.radiusMedia),
        ),
      ),
    );
  }
}

/// Title (up to two lines) and artist under a shelf cover.
///
/// The block is 52px. [ShimmerLoading.cardTextHeight] reserves 56, the same
/// slot [HomeLayoutMetrics.shelfTextHeight] gives [AlbumCard].
List<Widget> _shelfText(double width) {
  return [
    const SizedBox(height: 8),
    _Bone(width: width * 0.9, height: 14),
    const SizedBox(height: 2),
    _Bone(width: width * 0.62, height: 14),
    const SizedBox(height: 2),
    _Bone(width: width * 0.48, height: 12),
  ];
}

class _ShimmerCard extends StatelessWidget {
  final double cardWidth;

  const _ShimmerCard({this.cardWidth = 160});

  @override
  Widget build(BuildContext context) {
    final textBlock = _shelfText(cardWidth);

    // Same idea as [ShelfCardLayout]: when the parent (carousel/shelf)
    // bounds height, shrink the cover so the text bars never overflow.
    return SizedBox(
      width: cardWidth,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.hasBoundedHeight) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: cardWidth,
                      maxHeight: cardWidth,
                    ),
                    child: const AspectRatio(
                      aspectRatio: 1,
                      child: _ShimmerCover(),
                    ),
                  ),
                ),
                ...textBlock,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: cardWidth,
                height: cardWidth,
                child: const _ShimmerCover(),
              ),
              ...textBlock,
            ],
          );
        },
      ),
    );
  }
}

class _ShimmerVideoCard extends StatelessWidget {
  final double cardWidth;

  const _ShimmerVideoCard({required this.cardWidth});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(aspectRatio: 16 / 9, child: _ShimmerCover()),
          ..._shelfText(cardWidth),
        ],
      ),
    );
  }
}

/// Song row.
///
/// Flat rows match [SongTile]: 72 tall, cover 48 at radius 12, title,
/// artist, duration. [elevated] matches continue-listening cards.
class _ShimmerTile extends StatelessWidget {
  final double horizontalPadding;
  final bool elevated;
  final double artworkSize;

  const _ShimmerTile({
    this.horizontalPadding = 16,
    this.elevated = false,
    this.artworkSize = 48,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        SizedBox(
          width: artworkSize,
          height: artworkSize,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(
                Radius.circular(SonoraPulseTokens.radiusSm),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bone(width: width * 0.72, height: 16),
                  const SizedBox(height: 4),
                  _Bone(width: width * 0.45, height: 12),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        const _Bone(width: 36, height: 12),
      ],
    );

    if (!elevated) {
      return SizedBox(
        height: 72,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: row,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(SonoraPulseTokens.radiusSm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: row,
        ),
      ),
    );
  }
}

class _ShimmerCarousel extends StatelessWidget {
  final double cardWidth;
  final double horizontalPadding;
  final double itemGap;
  final bool video;

  const _ShimmerCarousel({
    this.cardWidth = 160,
    this.horizontalPadding = 16,
    this.itemGap = 8,
    this.video = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = video ? 180.0 : cardWidth + ShimmerLoading.cardTextHeight;
    return SizedBox(
      height: height,
      child: ListView.separated(
        primary: false,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: video ? 4 : 5,
        separatorBuilder: (_, _) => SizedBox(width: itemGap),
        itemBuilder: (_, _) => video
            ? _ShimmerVideoCard(cardWidth: cardWidth)
            : _ShimmerCard(cardWidth: cardWidth),
      ),
    );
  }
}

/// Skeleton of the mini player.
///
/// The 80px shelf is three zones: identity, transport, actions.
/// The compact 60px card stays one row, with artwork at 44.
class _ShimmerMiniPlayer extends StatelessWidget {
  const _ShimmerMiniPlayer();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 48.0;
        if (height >= kMiniPlayerShelfHeight - 4) {
          return _shelf(context);
        }
        return _compactRow(height);
      },
    );
  }

  Widget _shelf(BuildContext context) {
    final wide = isWideShell(MediaQuery.sizeOf(context));
    final art = wide ? 56.0 : 48.0;
    return Padding(
      key: const Key('mini-player-shelf'),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            flex: wide ? 4 : 5,
            child: Row(
              children: [
                _art(art),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 12,
                            width: 120,
                            child: ColoredBox(color: Colors.white),
                          ),
                          SizedBox(width: 8),
                          _ShimmerDisc(size: 28),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FractionallySizedBox(
                        widthFactor: 0.72,
                        alignment: Alignment.centerLeft,
                        child: const SizedBox(
                          height: 8,
                          child: ColoredBox(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: wide ? 5 : 4,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ShimmerDisc(size: 28),
                    SizedBox(width: 8),
                    _ShimmerDisc(size: 40),
                    SizedBox(width: 8),
                    _ShimmerDisc(size: 28),
                  ],
                ),
                SizedBox(height: 6),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    height: 4,
                    width: double.infinity,
                    child: ColoredBox(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ShimmerDisc(size: 28),
                _ShimmerDisc(size: 28),
                _ShimmerDisc(size: 28),
                _ShimmerDisc(size: 28),
                SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactRow(double height) {
    final art = height >= 52 ? 44.0 : (height < 40 ? height : 40.0);
    final button = height < 32 ? height : 32.0;
    final titleH = height >= 28 ? 12.0 : height * 0.28;
    final artistH = height >= 28 ? 8.0 : height * 0.2;
    final gap = height >= 28 ? 4.0 : 2.0;

    return Padding(
      key: const Key('mini-player-row'),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _art(art),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: titleH,
                  width: double.infinity,
                  child: const ColoredBox(color: Colors.white),
                ),
                SizedBox(height: gap),
                FractionallySizedBox(
                  widthFactor: 0.55,
                  child: SizedBox(
                    height: artistH,
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ShimmerDisc(size: button),
          _ShimmerDisc(size: button),
        ],
      ),
    );
  }

  Widget _art(double size) {
    return SizedBox(
      key: const Key('mini-player-art'),
      width: size,
      height: size,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(
            Radius.circular(SonoraPulseTokens.radiusSm),
          ),
        ),
      ),
    );
  }
}

class _ShimmerDisc extends StatelessWidget {
  final double size;

  const _ShimmerDisc({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
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
      height: 44,
      child: ListView.builder(
        primary: false,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 4,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => Padding(
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

class _ShimmerShelfHeader extends StatelessWidget {
  final double horizontalPadding;
  final double top;
  final double bottom;
  final bool showAction;

  const _ShimmerShelfHeader({
    this.horizontalPadding = 16,
    this.top = 12,
    this.bottom = 6,
    this.showAction = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        top,
        horizontalPadding,
        bottom,
      ),
      child: Row(
        children: [
          const _Bone(width: 160, height: 16),
          const Spacer(),
          if (showAction) const _Bone(width: 72, height: 12),
        ],
      ),
    );
  }
}

class _ShimmerZoneHeader extends StatelessWidget {
  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final bool showDivider;

  const _ShimmerZoneHeader({
    this.horizontalPadding = 16,
    this.topPadding = 20,
    this.bottomPadding = 8,
    this.showDivider = true,
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
          child: const _Bone(width: 140, height: 22),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: const SizedBox(
              height: 1,
              child: ColoredBox(color: Colors.white),
            ),
          ),
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
    final childPad = sideBySide ? 0.0 : horizontalPadding;
    final continueBlock = _continueBlock(childPad);
    final mixesBlock = _mixesBlock(childPad);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: zoneGap / 2),
      child: sideBySide
          ? Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                key: const Key('home-quick-row'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 55, child: continueBlock),
                  SizedBox(width: zoneGap),
                  Expanded(flex: 45, child: mixesBlock),
                ],
              ),
            )
          : Column(
              key: const Key('home-quick-row'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                continueBlock,
                SizedBox(height: zoneGap),
                mixesBlock,
              ],
            ),
    );
  }

  Widget _continueBlock(double pad) {
    final artwork = sideBySide ? 56.0 : 48.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShimmerShelfHeader(horizontalPadding: pad, top: 8, bottom: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Column(
            children: [
              for (var i = 0; i < 5; i++)
                _ShimmerTile(elevated: true, artworkSize: artwork),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _mixesBlock(double pad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShimmerShelfHeader(horizontalPadding: pad, showAction: false),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                const Expanded(child: _ShimmerMixCard()),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ShimmerMixCard extends StatelessWidget {
  const _ShimmerMixCard();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AspectRatio(aspectRatio: 1, child: _ShimmerCover()),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bone(width: width * 0.72, height: 14),
                  const SizedBox(height: 2),
                  _Bone(width: width * 0.92, height: 12),
                  const SizedBox(height: 2),
                  _Bone(width: width * 0.6, height: 12),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShimmerHero extends StatelessWidget {
  final double horizontalPadding;
  final double heroHeight;
  final double viewportFraction;
  final bool showHeader;
  final double headerTop;
  final double headerBottom;

  const _ShimmerHero({
    this.horizontalPadding = 16,
    this.heroHeight = 180,
    this.viewportFraction = 1,
    this.showHeader = false,
    this.headerTop = 12,
    this.headerBottom = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          _ShimmerShelfHeader(
            horizontalPadding: horizontalPadding,
            top: headerTop,
            bottom: headerBottom,
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final fraction = viewportFraction.clamp(0.4, 1.0);
            final cardWidth = fraction >= 0.99
                ? constraints.maxWidth - horizontalPadding * 2
                : constraints.maxWidth * fraction;
            return SizedBox(
              height: heroHeight,
              child: ListView(
                primary: false,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                children: [
                  SizedBox(width: cardWidth, child: _card()),
                  if (fraction < 0.99) ...[
                    const SizedBox(width: 8),
                    SizedBox(width: cardWidth, child: _card()),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _card() {
    final isCompact = heroHeight <= 180;
    final art = (isCompact ? heroHeight - 24 : heroHeight - 32).clamp(
      80.0,
      140.0,
    );
    final gap = isCompact ? 12.0 : 20.0;
    final play = isCompact ? 36.0 : 44.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(SonoraPulseTokens.radiusMedia),
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        child: Row(
          children: [
            SizedBox(
              width: art,
              height: art,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(
                    Radius.circular(SonoraPulseTokens.radiusSm),
                  ),
                ),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      _Bone(width: width * 0.85, height: 16),
                      const SizedBox(height: 4),
                      _Bone(width: width * 0.55, height: 12),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _ShimmerDisc(size: play),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
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
          const _Bone(width: 88, height: 20),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              primary: false,
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                const widths = [96.0, 148.0, 120.0];
                return _Bone(
                  width: widths[index],
                  height: 36,
                  radius: SonoraPulseTokens.radiusPill,
                );
              },
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
  final double headerTop;
  final double headerBottom;

  const _ShimmerSection({
    this.cardWidth = 160,
    this.horizontalPadding = 16,
    this.shelfHeight = 216,
    this.headerTop = 12,
    this.headerBottom = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShimmerShelfHeader(
          horizontalPadding: horizontalPadding,
          top: headerTop,
          bottom: headerBottom,
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

class _ShimmerArtistShelf extends StatelessWidget {
  final double horizontalPadding;
  final double avatarSize;
  final double headerTop;
  final double headerBottom;

  const _ShimmerArtistShelf({
    this.horizontalPadding = 16,
    this.avatarSize = 64,
    this.headerTop = 12,
    this.headerBottom = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShimmerShelfHeader(
          horizontalPadding: horizontalPadding,
          top: headerTop,
          bottom: headerBottom,
        ),
        SizedBox(
          height: avatarSize + 36,
          child: ListView.separated(
            primary: false,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            itemCount: 6,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, _) => SizedBox(
              width: avatarSize + 8,
              child: Column(
                children: [
                  _ShimmerDisc(size: avatarSize),
                  const SizedBox(height: 8),
                  _Bone(width: avatarSize * 0.8, height: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShimmerMediaGrid extends StatelessWidget {
  final double cardWidth;
  final double horizontalPadding;
  final int columns;
  final int itemCount;
  final double spacing;
  final double headerTop;
  final double headerBottom;

  const _ShimmerMediaGrid({
    this.cardWidth = 160,
    this.horizontalPadding = 16,
    this.columns = 4,
    this.itemCount = 8,
    this.spacing = 12,
    this.headerTop = 12,
    this.headerBottom = 6,
  });

  @override
  Widget build(BuildContext context) {
    final columns = this.columns < 1 ? 1 : this.columns;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShimmerShelfHeader(
          horizontalPadding: horizontalPadding,
          top: headerTop,
          bottom: headerBottom,
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cell =
                  (constraints.maxWidth - (columns - 1) * spacing) / columns;
              final rows = <Widget>[];
              for (var i = 0; i < itemCount; i += columns) {
                final count = (itemCount - i).clamp(0, columns);
                rows.add(
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i + columns < itemCount ? spacing : 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var j = 0; j < count; j++) ...[
                          if (j > 0) SizedBox(width: spacing),
                          _ShimmerCard(cardWidth: cell),
                        ],
                      ],
                    ),
                  ),
                );
              }
              return Column(children: rows);
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ShimmerMoodSection extends StatelessWidget {
  final double horizontalPadding;

  const _ShimmerMoodSection({this.horizontalPadding = 16});

  @override
  Widget build(BuildContext context) {
    const widths = [88.0, 120.0, 72.0, 140.0, 96.0, 110.0];
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Bone(width: 140, height: 20),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final width in widths)
                _Bone(
                  width: width,
                  height: 32,
                  radius: SonoraPulseTokens.radiusPill,
                ),
            ],
          ),
        ],
      ),
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
    return const SizedBox(
      height: 48,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 8, 0),
        child: Row(
          children: [
            _ShimmerDisc(size: 18),
            SizedBox(width: 8),
            _Bone(width: 100, height: 12),
            SizedBox(width: 8),
            _Bone(width: 28, height: 16, radius: 10),
            Spacer(),
            _Bone(width: 64, height: 12),
          ],
        ),
      ),
    );
  }
}

class _ShimmerQueueTile extends StatelessWidget {
  const _ShimmerQueueTile();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(width: 3),
            SizedBox(width: 10),
            SizedBox(
              width: 48,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bone(width: width * 0.72, height: 14),
                      const SizedBox(height: 2),
                      _Bone(width: width * 0.48, height: 12),
                    ],
                  );
                },
              ),
            ),
            _ShimmerDisc(size: 28),
          ],
        ),
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
    return ListView.separated(
      primary: false,
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, _) => _ShimmerCard(cardWidth: cardWidth),
    );
  }
}

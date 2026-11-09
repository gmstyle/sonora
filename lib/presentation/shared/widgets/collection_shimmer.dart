import 'package:material_ui/material_ui.dart';

import '../../../core/theme/sonora_pulse_tokens.dart';
import '../../../core/utils/layout_breakpoints.dart';
import 'facet_wide_scaffold.dart';
import 'shimmer_loading.dart';

/// Grid shape shared by a Library tab and its loading skeleton.
enum LibraryCollectionStyle {
  /// Albums, playlists, podcasts: 2 columns on compact, else 170px cells.
  media,

  /// Artists: 140px cells at every width, circular covers.
  artist,
}

/// The grid delegate a Library tab and [LibraryCollectionShimmer] both use.
SliverGridDelegate libraryCollectionGridDelegate({
  required bool compact,
  required LibraryCollectionStyle style,
}) {
  const spacing = 16.0;
  if (style == LibraryCollectionStyle.artist) {
    return const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 140,
      childAspectRatio: 0.68,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
    );
  }
  if (compact) {
    return const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: 0.68,
    );
  }
  return const SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 170,
    mainAxisSpacing: spacing,
    crossAxisSpacing: spacing,
    childAspectRatio: 0.68,
  );
}

/// Library loading for the current view: a tile list, or that tab's grid.
class LibraryCollectionShimmer extends StatelessWidget {
  final bool grid;
  final LibraryCollectionStyle style;
  final int itemCount;

  const LibraryCollectionShimmer({
    super.key,
    required this.grid,
    this.style = LibraryCollectionStyle.media,
    this.itemCount = 8,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 16;
    if (!grid) {
      return ListView.builder(
        itemCount: itemCount,
        padding: EdgeInsets.only(top: 8, bottom: bottom),
        itemBuilder: (_, _) =>
            const ShimmerLoading(variant: ShimmerVariant.tile),
      );
    }

    final compact = isCompactShell(MediaQuery.sizeOf(context));
    return ShimmerLoading.wrap(
      context,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
        gridDelegate: libraryCollectionGridDelegate(
          compact: compact,
          style: style,
        ),
        itemCount: itemCount,
        itemBuilder: (_, _) =>
            _MediaCell(circle: style == LibraryCollectionStyle.artist),
      ),
    );
  }
}

/// Wide Search "All" loading: one shelf grid, using the facet column count.
class SearchShelfShimmer extends StatelessWidget {
  const SearchShelfShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = facetMediaColumnCount(constraints.maxWidth);
        return ShimmerLoading.wrap(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 20, 0, 12),
                child: _Bar(width: 140, height: 16),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: columns * 2,
                itemBuilder: (_, _) => const _MediaCell(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MediaCell extends StatelessWidget {
  final bool circle;

  const _MediaCell({this.circle = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: circle
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: circle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: circle
                  ? null
                  : BorderRadius.circular(SonoraPulseTokens.radiusMedia),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: _Bar(width: 72, height: 12),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double width;
  final double height;

  const _Bar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: const ColoredBox(color: Colors.white),
    );
  }
}

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/thumbnail_widget.dart';
import '../tv_metrics.dart';
import 'tv_focusable.dart';

/// Poster-style catalog card for TV shelves and grids.
class TvPosterCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback? onSelect;
  final VoidCallback? onLongSelect;
  final VoidCallback? onLeftAtEdge;
  final bool autofocus;
  final double width;
  final double? imageHeight;
  final ThumbnailShape shape;
  final FocusNode? focusNode;

  const TvPosterCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.onSelect,
    this.onLongSelect,
    this.onLeftAtEdge,
    this.autofocus = false,
    this.width = TvMetrics.shelfCardWidth,
    this.imageHeight,
    this.shape = ThumbnailShape.rounded,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: TvFocusable(
        autofocus: autofocus,
        focusNode: focusNode,
        onSelect: onSelect,
        onLongSelect: onLongSelect,
        onLeftAtEdge: onLeftAtEdge,
        borderRadius: BorderRadius.circular(TvMetrics.cardRadius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textH = TvMetrics.shelfCardTextHeight;
            final maxW = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : width;
            final maxH = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : double.infinity;
            final preferred = imageHeight ?? width;
            final img = math.min(
              preferred,
              math.min(
                maxW,
                maxH.isFinite ? math.max(0.0, maxH - textH) : preferred,
              ),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ThumbnailWidget(
                  imageUrl: imageUrl,
                  size: img,
                  shape: shape,
                  borderRadius: TvMetrics.cardRadius,
                ),
                SizedBox(
                  height: textH,
                  width: maxW,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.15,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

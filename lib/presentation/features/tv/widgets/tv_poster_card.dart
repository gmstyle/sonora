import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/thumbnail_widget.dart';
import '../tv_metrics.dart';
import 'tv_focusable.dart';

/// Poster-style framed catalog card for TV shelves and grids.
class TvPosterCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final Widget? placeholderOverride;
  final VoidCallback? onSelect;
  final VoidCallback? onLongSelect;
  final VoidCallback? onLeftAtEdge;
  final ValueChanged<bool>? onFocusChange;
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
    this.placeholderOverride,
    this.onSelect,
    this.onLongSelect,
    this.onLeftAtEdge,
    this.onFocusChange,
    this.autofocus = false,
    this.width = TvMetrics.shelfCardWidth,
    this.imageHeight,
    this.shape = ThumbnailShape.rounded,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const pad = TvMetrics.shelfCardPadding;

    return SizedBox(
      width: width,
      child: TvFocusable(
        autofocus: autofocus,
        focusNode: focusNode,
        onSelect: onSelect,
        onLongSelect: onLongSelect,
        onLeftAtEdge: onLeftAtEdge,
        onFocusChange: onFocusChange,
        borderRadius: BorderRadius.circular(TvMetrics.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(pad),
          decoration: BoxDecoration(
            color: TvColors.surfaceCard,
            borderRadius: BorderRadius.circular(TvMetrics.cardRadius),
            border: Border.all(color: TvColors.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textH = TvMetrics.shelfCardTextHeight;
              final maxW = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : width - (pad * 2);
              final maxH = constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : double.infinity;
              final preferred = (imageHeight ?? width) - (pad * 2);
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
                  SizedBox(
                    width: img,
                    height: img,
                    child: placeholderOverride != null && imageUrl == null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(
                              shape == ThumbnailShape.circle ? img / 2 : 8,
                            ),
                            child: placeholderOverride,
                          )
                        : ThumbnailWidget(
                            imageUrl: imageUrl,
                            size: img,
                            shape: shape,
                            borderRadius: 8,
                          ),
                  ),
                  SizedBox(
                    height: textH,
                    width: maxW,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: TvColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: TvColors.textSecondary,
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
      ),
    );
  }
}

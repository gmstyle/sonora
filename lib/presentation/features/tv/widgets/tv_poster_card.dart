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
    final imgSize = imageHeight ?? width;

    return SizedBox(
      width: width,
      child: TvFocusable(
        autofocus: autofocus,
        focusNode: focusNode,
        onSelect: onSelect,
        onLongSelect: onLongSelect,
        onLeftAtEdge: onLeftAtEdge,
        borderRadius: BorderRadius.circular(TvMetrics.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ThumbnailWidget(
              imageUrl: imageUrl,
              size: imgSize,
              shape: shape,
              borderRadius: TvMetrics.cardRadius,
            ),
            SizedBox(
              height: TvMetrics.shelfCardTextHeight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../shared/widgets/thumbnail_widget.dart';
import '../tv_metrics.dart';
import 'tv_focusable.dart';

/// Large poster-style card for Android TV shelves and grids.
class TvPosterCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? thumbnailUrl;
  final VoidCallback? onSelect;
  final VoidCallback? onLongSelect;
  final bool autofocus;
  final double width;
  final bool circular;

  const TvPosterCard({
    super.key,
    required this.title,
    this.subtitle,
    this.thumbnailUrl,
    this.onSelect,
    this.onLongSelect,
    this.autofocus = false,
    this.width = TvMetrics.cardWidth,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageSize =
        circular ? width : TvMetrics.cardArtSize.clamp(0.0, width).toDouble();
    return SizedBox(
      width: width,
      child: TvFocusable(
        autofocus: autofocus,
        onSelect: onSelect,
        onLongSelect: onLongSelect,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ThumbnailWidget(
              imageUrl: thumbnailUrl,
              size: imageSize.toDouble(),
              shape: circular ? ThumbnailShape.circle : ThumbnailShape.rounded,
              borderRadius: circular ? null : 16,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/thumbnail_widget.dart';
import '../tv_metrics.dart';
import 'tv_focusable.dart';

/// Landscape featured item for the ATV browser home (first horizontal row).
class TvFeaturedCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback? onSelect;
  final VoidCallback? onLeftAtEdge;
  final bool autofocus;

  const TvFeaturedCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.onSelect,
    this.onLeftAtEdge,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: TvMetrics.featuredCardWidth,
      height: TvMetrics.featuredCardHeight,
      child: TvFocusable(
        autofocus: autofocus,
        onSelect: onSelect,
        onLeftAtEdge: onLeftAtEdge,
        borderRadius: BorderRadius.circular(TvMetrics.cardRadius),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TvMetrics.cardRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: colorScheme.surfaceContainerHighest),
              if (imageUrl != null)
                ThumbnailWidget(
                  imageUrl: imageUrl,
                  size: TvMetrics.featuredCardWidth,
                  shape: ThumbnailShape.square,
                  borderRadius: 0,
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      colorScheme.surface.withValues(alpha: 0.92),
                      colorScheme.surface.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

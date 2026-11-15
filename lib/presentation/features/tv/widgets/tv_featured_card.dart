import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/thumbnail_widget.dart';
import '../tv_metrics.dart';
import 'tv_focusable.dart';

/// Landscape 16:9 framed card for the ATV browser home ("Continue Listening").
class TvFeaturedCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? badge;
  final VoidCallback? onSelect;
  final VoidCallback? onLongSelect;
  final VoidCallback? onLeftAtEdge;
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;

  const TvFeaturedCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.badge,
    this.onSelect,
    this.onLongSelect,
    this.onLeftAtEdge,
    this.onFocusChange,
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
        onLongSelect: onLongSelect,
        onLeftAtEdge: onLeftAtEdge,
        onFocusChange: onFocusChange,
        borderRadius: BorderRadius.circular(TvMetrics.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(TvMetrics.shelfCardPadding),
          decoration: BoxDecoration(
            color: TvColors.surfaceCard,
            borderRadius: BorderRadius.circular(TvMetrics.cardRadius),
            border: Border.all(color: TvColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: TvMetrics.featuredCardImageHeight,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: TvColors.surfaceButton),
                      if (imageUrl != null)
                        FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: ThumbnailWidget(
                            imageUrl: imageUrl,
                            size: TvMetrics.featuredCardWidth,
                            shape: ThumbnailShape.square,
                            borderRadius: 0,
                          ),
                        ),
                      if (badge != null && badge!.isNotEmpty)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: TvColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: TvColors.textSecondary,
                    height: 1.2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../../../shared/widgets/thumbnail_widget.dart';
import '../tv_metrics.dart';
import 'tv_focusable.dart';

/// Full-bleed hero block for the TV home catalog.
class TvHero extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;
  final bool autofocus;

  const TvHero({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    required this.primaryLabel,
    this.onPrimary,
    this.onSecondary,
    this.secondaryLabel,
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: TvMetrics.heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            ColoredBox(
              color: colorScheme.surfaceContainerHighest,
              child: Opacity(
                opacity: 0.55,
                child: ThumbnailWidget(
                  imageUrl: imageUrl,
                  size: 960,
                  shape: ThumbnailShape.square,
                  borderRadius: 0,
                ),
              ),
            )
          else
            ColoredBox(color: colorScheme.surfaceContainerHighest),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  colorScheme.surface.withValues(alpha: 0.92),
                  colorScheme.surface.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(TvMetrics.contentPadding),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TvFocusable(
                          autofocus: autofocus,
                          onSelect: onPrimary,
                          borderRadius: BorderRadius.circular(28),
                          child: FilledButton(
                            onPressed: onPrimary,
                            child: Text(primaryLabel),
                          ),
                        ),
                        if (onSecondary != null && secondaryLabel != null) ...[
                          const SizedBox(width: 12),
                          TvFocusable(
                            onSelect: onSecondary,
                            borderRadius: BorderRadius.circular(28),
                            child: FilledButton.tonal(
                              onPressed: onSecondary,
                              child: Text(secondaryLabel!),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/widgets/thumbnail_widget.dart';
import '../tv_metrics.dart';
import 'tv_focusable.dart';

/// JetFit-style inset hero card for the TV home catalog.
class TvHero extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final String? secondaryLabel;
  final bool autofocus;
  final int pageIndex;
  final int pageCount;
  final VoidCallback? onLeftAtEdge;

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
    this.pageIndex = 0,
    this.pageCount = 1,
    this.onLeftAtEdge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TvMetrics.contentPadding,
        28,
        TvMetrics.contentPadding,
        8,
      ),
      child: TvFocusable(
        autofocus: autofocus,
        onSelect: onPrimary,
        onLeftAtEdge: onLeftAtEdge,
        borderRadius: BorderRadius.circular(TvMetrics.heroCardRadius),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TvMetrics.heroCardRadius),
          child: SizedBox(
            height: TvMetrics.heroCardHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: colorScheme.surfaceContainerHighest),
                if (imageUrl != null)
                  Opacity(
                    opacity: 0.85,
                    child: ThumbnailWidget(
                      imageUrl: imageUrl,
                      size: 960,
                      shape: ThumbnailShape.square,
                      borderRadius: 0,
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        colorScheme.surface.withValues(alpha: 0.94),
                        colorScheme.surface.withValues(alpha: 0.55),
                        colorScheme.surface.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.35, 0.65, 1.0],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(36, 28, 36, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: onPrimary,
                            icon: const Icon(LucideIcons.play, size: 20),
                            label: Text(primaryLabel),
                          ),
                          if (onSecondary != null &&
                              secondaryLabel != null) ...[
                            const SizedBox(width: 12),
                            FilledButton.tonal(
                              onPressed: onSecondary,
                              child: Text(secondaryLabel!),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (pageCount > 1)
                  Positioned(
                    right: 28,
                    bottom: 24,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < pageCount; i++)
                          Container(
                            width: i == pageIndex ? 18 : 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: i == pageIndex
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurface.withValues(
                                      alpha: 0.35,
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:material_ui/material_ui.dart';

import '../tv_metrics.dart';
import 'tv_focusable.dart';

/// Landscape mood / genre card for an ATV horizontal browse row.
///
/// [BrowseChip] has no artwork — fill uses a deterministic Pulse tint from
/// [title] so the row still reads as image cards.
class TvCategoryCard extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onLeftAtEdge;
  final bool autofocus;

  const TvCategoryCard({
    super.key,
    required this.title,
    this.selected = false,
    this.onSelect,
    this.onLeftAtEdge,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tint = _tintFor(title, colorScheme);

    return SizedBox(
      width: TvMetrics.categoryCardWidth,
      height: TvMetrics.categoryCardHeight,
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
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tint.withValues(alpha: 0.85),
                      colorScheme.surfaceContainerHighest,
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      colorScheme.surface.withValues(alpha: 0.88),
                      colorScheme.surface.withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
              if (selected)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary, width: 3),
                    borderRadius: BorderRadius.circular(TvMetrics.cardRadius),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _tintFor(String title, ColorScheme scheme) {
    final hues = <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.secondary,
      scheme.primaryContainer,
      scheme.tertiaryContainer,
      scheme.secondaryContainer,
    ];
    var hash = 0;
    for (final c in title.codeUnits) {
      hash = (hash + c) * 31;
    }
    return hues[hash.abs() % hues.length];
  }
}

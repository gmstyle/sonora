import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tv_metrics.dart';
import 'tv_focusable.dart';

/// Compact horizontal gradient pill card for mood / genre rows on ATV.
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
    final palette = _paletteFor(title, colorScheme);

    return SizedBox(
      width: TvMetrics.categoryCardWidth,
      height: TvMetrics.categoryCardHeight,
      child: TvFocusable(
        autofocus: autofocus,
        onSelect: onSelect,
        onLeftAtEdge: onLeftAtEdge,
        borderRadius: BorderRadius.circular(TvMetrics.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                palette.$1.withValues(alpha: 0.65),
                palette.$2.withValues(alpha: 0.65),
              ],
            ),
            borderRadius: BorderRadius.circular(TvMetrics.cardRadius),
            border: Border.all(
              color: selected ? colorScheme.primary : TvColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  palette.$3,
                  size: 18,
                  color: selected ? colorScheme.primary : TvColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: TvColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static (Color, Color, IconData) _paletteFor(
    String title,
    ColorScheme scheme,
  ) {
    final options = <(Color, Color, IconData)>[
      (const Color(0xFF4C1D95), const Color(0xFF312E81), LucideIcons.zap),
      (const Color(0xFF1E3A8A), const Color(0xFF155E75), LucideIcons.moon),
      (const Color(0xFF065F46), const Color(0xFF115E59), LucideIcons.coffee),
      (const Color(0xFF92400E), const Color(0xFF881337), LucideIcons.sparkles),
      (
        const Color(0xFF3730A3),
        const Color(0xFF6B21A8),
        LucideIcons.headphones,
      ),
      (scheme.primaryContainer, const Color(0xFF0F766E), LucideIcons.disc3),
    ];
    var hash = 0;
    for (final c in title.codeUnits) {
      hash = (hash + c) * 31;
    }
    return options[hash.abs() % options.length];
  }
}

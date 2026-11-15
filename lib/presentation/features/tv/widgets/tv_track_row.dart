import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tv_metrics.dart';
import 'tv_focusable.dart';

/// Tall focusable track row card for TV entity lists.
class TvTrackRow extends StatelessWidget {
  final int index;
  final String title;
  final String? subtitle;
  final String? duration;
  final bool isExplicit;
  final bool isPlaying;
  final bool enabled;
  final VoidCallback? onSelect;
  final VoidCallback? onLongSelect;
  final VoidCallback? onLeftAtEdge;
  final bool autofocus;

  const TvTrackRow({
    super.key,
    required this.index,
    required this.title,
    this.subtitle,
    this.duration,
    this.isExplicit = false,
    this.isPlaying = false,
    this.enabled = true,
    this.onSelect,
    this.onLongSelect,
    this.onLeftAtEdge,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fg = !enabled
        ? TvColors.textSecondary.withValues(alpha: 0.4)
        : isPlaying
        ? colorScheme.primary
        : TvColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: TvFocusable(
        autofocus: autofocus,
        onSelect: enabled ? onSelect : null,
        onLongSelect: enabled ? onLongSelect : null,
        onLeftAtEdge: onLeftAtEdge,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isPlaying
                ? colorScheme.primary.withValues(alpha: 0.12)
                : TvColors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPlaying
                  ? colorScheme.primary.withValues(alpha: 0.35)
                  : TvColors.borderFaint,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: isPlaying
                    ? Icon(
                        LucideIcons.play,
                        size: 14,
                        color: colorScheme.primary,
                      )
                    : Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: enabled
                              ? TvColors.textSecondary
                              : TvColors.textSecondary.withValues(alpha: 0.4),
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isExplicit)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: TvColors.surfaceButton,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'E',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: TvColors.textSecondary,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isPlaying
                              ? colorScheme.primary.withValues(alpha: 0.8)
                              : enabled
                              ? TvColors.textSecondary
                              : fg,
                        ),
                      ),
                  ],
                ),
              ),
              if (!enabled)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    LucideIcons.ban,
                    size: 16,
                    color: colorScheme.error.withValues(alpha: 0.7),
                  ),
                )
              else if (duration != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    duration!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
                      color: isPlaying
                          ? colorScheme.primary
                          : TvColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

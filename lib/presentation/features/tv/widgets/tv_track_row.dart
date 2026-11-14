import 'package:material_ui/material_ui.dart';

import 'tv_focusable.dart';

/// Tall focusable track row for TV entity lists.
class TvTrackRow extends StatelessWidget {
  final int index;
  final String title;
  final String? subtitle;
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
    final fg = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TvFocusable(
        autofocus: autofocus,
        onSelect: enabled ? onSelect : null,
        onLongSelect: enabled ? onLongSelect : null,
        onLeftAtEdge: onLeftAtEdge,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.titleMedium?.copyWith(color: fg),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: enabled ? colorScheme.onSurfaceVariant : fg,
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

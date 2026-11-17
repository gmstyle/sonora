import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tv_metrics.dart';
import 'tv_focusable.dart';

/// One labeled CTA for [TvEntityActionsBar].
class TvEntityAction {
  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onSelect;
  final bool filled;
  final bool autofocus;

  /// When non-null, tints the icon/label with [ColorScheme.primary].
  final bool active;

  const TvEntityAction({
    required this.id,
    required this.icon,
    required this.label,
    this.onSelect,
    this.filled = false,
    this.autofocus = false,
    this.active = false,
  });
}

/// Primary action row + overflow for ATV entity headers (content-detail).
class TvEntityActionsBar extends StatelessWidget {
  final List<TvEntityAction> actions;
  final VoidCallback? onOverflow;

  const TvEntityActionsBar({super.key, required this.actions, this.onOverflow});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final action in actions)
          TvFocusable(
            autofocus: action.autofocus,
            onSelect: action.onSelect,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: action.filled
                    ? colorScheme.primary
                    : action.active
                    ? colorScheme.primary.withValues(alpha: 0.16)
                    : TvColors.surfaceButton,
                borderRadius: BorderRadius.circular(12),
                border: action.filled
                    ? null
                    : Border.all(
                        color: action.active
                            ? colorScheme.primary.withValues(alpha: 0.4)
                            : TvColors.border,
                      ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    action.icon,
                    size: 16,
                    color: action.filled
                        ? colorScheme.onPrimary
                        : action.active
                        ? colorScheme.primary
                        : TvColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    action.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: action.filled
                          ? colorScheme.onPrimary
                          : action.active
                          ? colorScheme.primary
                          : TvColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (onOverflow != null)
          TvFocusable(
            onSelect: onOverflow,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: TvColors.surfaceButton,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TvColors.border),
              ),
              child: const Icon(
                LucideIcons.ellipsisVertical,
                size: 18,
                color: TvColors.textPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

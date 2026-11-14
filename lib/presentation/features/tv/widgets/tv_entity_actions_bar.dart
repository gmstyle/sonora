import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/widgets/thumbnail_widget.dart';
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

/// JetFit-style primary action row + overflow for TV entity headers.
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
            borderRadius: BorderRadius.circular(28),
            child: action.filled
                ? FilledButton.icon(
                    onPressed: action.onSelect,
                    icon: Icon(action.icon),
                    label: Text(action.label),
                  )
                : FilledButton.tonalIcon(
                    onPressed: action.onSelect,
                    icon: Icon(
                      action.icon,
                      color: action.active
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    label: Text(
                      action.label,
                      style: action.active
                          ? TextStyle(color: colorScheme.primary)
                          : null,
                    ),
                  ),
          ),
        if (onOverflow != null)
          TvFocusable(
            onSelect: onOverflow,
            borderRadius: BorderRadius.circular(28),
            child: IconButton.filledTonal(
              onPressed: onOverflow,
              icon: const Icon(LucideIcons.ellipsisVertical),
            ),
          ),
      ],
    );
  }
}

/// Shared immersive entity chrome: full-bleed art, scrim, title, actions.
class TvImmersiveEntityHeader extends StatelessWidget {
  final String? imageUrl;
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final String? description;
  final Widget actions;
  final VoidCallback? onBack;
  final double height;

  const TvImmersiveEntityHeader({
    super.key,
    this.imageUrl,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.description,
    required this.actions,
    this.onBack,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: colorScheme.surfaceContainerHighest),
          if (imageUrl != null)
            Opacity(
              opacity: 0.55,
              child: ThumbnailWidget(
                imageUrl: imageUrl,
                size: 1200,
                shape: ThumbnailShape.square,
                borderRadius: 0,
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  colorScheme.surface,
                  colorScheme.surface.withValues(alpha: 0.85),
                  colorScheme.surface.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TvMetrics.contentPadding,
              28,
              TvMetrics.contentPadding,
              24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onBack != null)
                  TvFocusable(
                    onSelect: onBack,
                    borderRadius: BorderRadius.circular(28),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(LucideIcons.arrowLeft, size: 28),
                    ),
                  ),
                const Spacer(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow != null && eyebrow!.isNotEmpty)
                        Text(
                          eyebrow!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (eyebrow != null && eyebrow!.isNotEmpty)
                        const SizedBox(height: 8),
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
                      if (description != null && description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      actions,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

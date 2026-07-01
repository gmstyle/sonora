import 'package:flutter/material.dart';

/// A small inline badge displaying "E" for explicit content.
class ExplicitBadge extends StatelessWidget {
  /// Optional spacing/widget prepended before the badge pill itself.
  final Widget? leading;

  const ExplicitBadge({super.key, this.leading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        'E',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          fontWeight: FontWeight.bold,
          fontSize: 9,
          height: 1.0,
        ),
      ),
    );

    if (leading == null) return badge;

    return Row(mainAxisSize: MainAxisSize.min, children: [leading!, badge]);
  }
}

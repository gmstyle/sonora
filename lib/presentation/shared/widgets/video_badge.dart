import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// Shared "MV" badge used across cards, tiles, and the mini-player.
///
/// [leading] — optional widget inserted before the badge pill (e.g. a
/// `SizedBox` spacer when the badge is rendered inline with text).
class VideoBadge extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// Widget placed before the badge pill. Useful when embedding the badge
  /// in a `Row` next to song-title text so a small gap can be added without
  /// wrapping the whole thing in an extra `Row`.
  final Widget? leading;

  const VideoBadge({
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    this.borderRadius = 4,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        AppLocalizations.of(context)!.mv,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onTertiaryContainer,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );

    if (leading == null) return badge;

    return Row(mainAxisSize: MainAxisSize.min, children: [leading!, badge]);
  }
}

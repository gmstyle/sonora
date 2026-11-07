import 'package:material_ui/material_ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Shared binary affinity control (like / follow / subscribe / save episode).
///
/// **Chrome (fill never carries the active signal):**
/// - Compact / icon-only: [IconButton], transparent.
/// - Tablet / wide: [FilledButton.tonalIcon], fill stays
///   `secondaryContainer`.
///
/// **Active signal (all shells and surfaces):**
/// - Icon swaps idle → active pair.
/// - Glyph (and label when present) use [activeColor].
/// - Idle glyph uses [ColorScheme.onSurfaceVariant].
///
/// Every affinity action tints with [ColorScheme.primary]. The icon pair
/// (heart, person, bookmark) is what distinguishes like, follow, and
/// subscribe. [ColorScheme.error] stays on destructive actions.
class DetailAffinityButton extends StatelessWidget {
  final bool iconOnly;
  final bool isActive;
  final bool enabled;
  final IconData idleIcon;
  final IconData activeIcon;
  final String idleLabel;
  final String activeLabel;
  final String? tooltip;
  final Color activeColor;
  final VoidCallback? onPressed;

  const DetailAffinityButton({
    super.key,
    required this.iconOnly,
    required this.isActive,
    required this.idleIcon,
    required this.activeIcon,
    required this.idleLabel,
    required this.activeLabel,
    required this.activeColor,
    this.tooltip,
    this.onPressed,
    this.enabled = true,
  });

  /// Material heart pair for Like actions (outline → filled).
  static const IconData likeIdle = Icons.favorite_border;
  static const IconData likeActive = Icons.favorite;

  /// Lucide bookmark pair for Subscribe / Save episode.
  static const IconData bookmarkIdle = LucideIcons.bookmark;
  static const IconData bookmarkActive = LucideIcons.bookmarkCheck;

  /// Lucide person pair for Follow.
  static const IconData followIdle = LucideIcons.userPlus;
  static const IconData followActive = LucideIcons.userCheck;

  /// Follow, subscribe, save, and like active tint (brand primary).
  static Color brandColor(ColorScheme scheme) => scheme.primary;

  /// Like uses the same brand tint as the other affinity actions.
  static Color likeColor(ColorScheme scheme) => brandColor(scheme);

  /// Leading / glyph color for list rows and icon buttons.
  static Color glyphColor(
    ColorScheme scheme, {
    required bool isActive,
    required Color activeColor,
  }) {
    return isActive ? activeColor : scheme.onSurfaceVariant;
  }

  IconData get _icon => isActive ? activeIcon : idleIcon;
  String get _label => isActive ? activeLabel : idleLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tip = tooltip ?? _label;
    final glyph = glyphColor(
      scheme,
      isActive: isActive,
      activeColor: activeColor,
    );

    if (iconOnly) {
      return IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(_icon),
        color: glyph,
        tooltip: tip,
      );
    }

    return FilledButton.tonalIcon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(_icon),
      label: Text(_label),
      // Fill stays secondaryContainer. Only the foreground carries state.
      style: isActive
          ? FilledButton.styleFrom(foregroundColor: activeColor)
          : FilledButton.styleFrom(
              foregroundColor: scheme.onSecondaryContainer,
            ),
    );
  }
}

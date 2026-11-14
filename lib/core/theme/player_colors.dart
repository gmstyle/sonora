import 'package:material_ui/material_ui.dart';

import 'brand_accent.dart';
import 'sonora_pulse_tokens.dart';

/// Custom [ThemeExtension] that centralises every colour token used by the
/// full-player surface and any screen that overlays artwork (Album, Artist,
/// Playlist SliverAppBar headers).
///
/// The player background is always visually dark — a heavily blurred artwork
/// image covered by a dark gradient + scrim — regardless of the system theme
/// (light / dark / amoled).  Standard [ColorScheme] tokens are designed for
/// surface-based UIs and produce unreadable text on this overlay.
///
/// By collecting all player-specific colours here, every widget in the player
/// tree reads from one place.  Future changes (e.g. a "sepia" player variant
/// or per-palette accent tinting) require editing only this file.
///
/// ### Usage
/// ```dart
/// final pc = Theme.of(context).extension<PlayerColors>()!;
/// Text('Title', style: TextStyle(color: pc.titlePrimary));
/// ```
@immutable
class PlayerColors extends ThemeExtension<PlayerColors> {
  // ── Text ──────────────────────────────────────────────────────────────────

  /// Primary track title / currently-active item.  Full white.
  final Color titlePrimary;

  /// Secondary titles (other queue items, collapsed app-bar title).
  final Color titleSecondary;

  /// Subtitle / artist name.
  final Color subtitle;

  /// Muted label: stats, year, duration, "Playing from" label.
  final Color labelMuted;

  // ── Icons ─────────────────────────────────────────────────────────────────

  /// Primary icon (chevron-down, active play icon, active like).
  final Color iconPrimary;

  /// Secondary icon (skip, share, queue toggle, remove button).
  final Color iconSecondary;

  // ── Scrim (top of artwork headers & full-player background) ───────────────

  /// Start colour of the top-edge dark scrim (status bar + toolbar zone).
  final Color topScrimStart;

  /// Mid-point colour of the top scrim (fades toward transparent).
  final Color topScrimMid;

  // ── Shimmer (artworkLarge variant used inside the player) ─────────────────

  /// Base / trough colour of the shimmer sweep.
  final Color shimmerBase;

  /// Highlight / peak colour of the shimmer sweep.
  final Color shimmerHighlight;

  /// Cyan brand accent used for the scrubber, play glow, and active titles.
  final Color accent;

  /// Azure end of the brand spectrum, paired with [accent] in gradients.
  final Color accentEnd;

  /// Glyph drawn on [accent].
  final Color accentInk;

  const PlayerColors({
    required this.titlePrimary,
    required this.titleSecondary,
    required this.subtitle,
    required this.labelMuted,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.topScrimStart,
    required this.topScrimMid,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.accent,
    required this.accentEnd,
    required this.accentInk,
  });

  /// Standard values used by all three app themes (light / dark / amoled).
  ///
  /// The player background is always a dark Pulse scrim, so these values are
  /// theme-invariant. [accent] is the brand cyan on that scrim.
  factory PlayerColors.standard() => const PlayerColors(
    titlePrimary: Color(0xFFFFFFFF),
    titleSecondary: Color(0xCCFFFFFF),
    subtitle: Color(0xFF94A3B8),
    labelMuted: Color(0xB394A3B8),
    iconPrimary: Color(0xFFFFFFFF),
    iconSecondary: Color(0xFFB9CACB),
    topScrimStart: Color(0xCC0F1026),
    topScrimMid: Color(0x660F1026),
    shimmerBase: Color(0xFF1E2038),
    shimmerHighlight: Color(0xFF2D2F54),
    accent: Color(0xFF00F2FE),
    accentEnd: Color(0xFF4FACFE),
    accentInk: Color(0xFF00373A),
  );

  /// Player accent for [accent]. Cyan returns [standard].
  factory PlayerColors.forAccent(BrandAccent accent) {
    if (accent == BrandAccent.cyan) return PlayerColors.standard();
    return PlayerColors.standard().copyWith(
      accent: accent.fill,
      accentEnd: accent.end,
      accentInk: accent.ink,
    );
  }

  // ── ThemeExtension contract ───────────────────────────────────────────────

  @override
  PlayerColors copyWith({
    Color? titlePrimary,
    Color? titleSecondary,
    Color? subtitle,
    Color? labelMuted,
    Color? iconPrimary,
    Color? iconSecondary,
    Color? topScrimStart,
    Color? topScrimMid,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? accent,
    Color? accentEnd,
    Color? accentInk,
  }) {
    return PlayerColors(
      titlePrimary: titlePrimary ?? this.titlePrimary,
      titleSecondary: titleSecondary ?? this.titleSecondary,
      subtitle: subtitle ?? this.subtitle,
      labelMuted: labelMuted ?? this.labelMuted,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      topScrimStart: topScrimStart ?? this.topScrimStart,
      topScrimMid: topScrimMid ?? this.topScrimMid,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      accent: accent ?? this.accent,
      accentEnd: accentEnd ?? this.accentEnd,
      accentInk: accentInk ?? this.accentInk,
    );
  }

  @override
  PlayerColors lerp(PlayerColors? other, double t) {
    if (other == null) return this;
    return PlayerColors(
      titlePrimary: Color.lerp(titlePrimary, other.titlePrimary, t)!,
      titleSecondary: Color.lerp(titleSecondary, other.titleSecondary, t)!,
      subtitle: Color.lerp(subtitle, other.subtitle, t)!,
      labelMuted: Color.lerp(labelMuted, other.labelMuted, t)!,
      iconPrimary: Color.lerp(iconPrimary, other.iconPrimary, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      topScrimStart: Color.lerp(topScrimStart, other.topScrimStart, t)!,
      topScrimMid: Color.lerp(topScrimMid, other.topScrimMid, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(
        shimmerHighlight,
        other.shimmerHighlight,
        t,
      )!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentEnd: Color.lerp(accentEnd, other.accentEnd, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
    );
  }

  /// Convenience accessor — throws if [PlayerColors] is not registered in the
  /// theme.  Use [maybeOf] in contexts where registration is uncertain.
  static PlayerColors of(BuildContext context) =>
      Theme.of(context).extension<PlayerColors>()!;

  /// Returns `null` if [PlayerColors] is not registered in the theme.
  static PlayerColors? maybeOf(BuildContext context) =>
      Theme.of(context).extension<PlayerColors>();

  @override
  String toString() =>
      'PlayerColors('
      'titlePrimary: $titlePrimary, '
      'titleSecondary: $titleSecondary, '
      'subtitle: $subtitle, '
      'labelMuted: $labelMuted'
      ')';
}

/// Play control gradient for the active brand accent.
BoxDecoration brandPlayDecoration(
  BuildContext context, {
  bool enabled = true,
  bool glow = true,
}) {
  final colors = PlayerColors.maybeOf(context);
  return SonoraPulseTokens.playControlDecoration(
    enabled: enabled,
    glow: glow,
    accent: colors?.accent,
    accentEnd: colors?.accentEnd,
  );
}

/// Dark glyph that sits on the play-control fill.
Color brandGlyphOnFill(BuildContext context) =>
    PlayerColors.maybeOf(context)?.accentInk ?? SonoraPulseTokens.onPrimary;

/// Vertical brand spectrum. Pass [horizontal] for the seek strip.
LinearGradient brandSpectrumOf(
  BuildContext context, {
  bool horizontal = false,
}) {
  final colors = PlayerColors.maybeOf(context);
  return LinearGradient(
    begin: horizontal ? Alignment.centerLeft : Alignment.topCenter,
    end: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
    colors: [
      colors?.accent ?? SonoraPulseTokens.gradientStart,
      colors?.accentEnd ?? SonoraPulseTokens.gradientEnd,
    ],
  );
}

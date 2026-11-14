import 'package:material_ui/material_ui.dart';

/// Brand fill chosen in Appearance.
///
/// Surfaces stay Sonora Pulse. Only the cyan role moves: primary fills,
/// the player accent, and the play-control gradient.
enum BrandAccent {
  cyan(
    Color(0xFF00F2FE),
    Color(0xFF4FACFE),
    Color(0xFF00373A),
    Color(0xFF00696F),
  ),
  azure(
    Color(0xFF38BDF8),
    Color(0xFF2563EB),
    Color(0xFF082F49),
    Color(0xFF0369A1),
  ),
  indigo(
    Color(0xFF818CF8),
    Color(0xFF4F46E5),
    Color(0xFF1E1B4B),
    Color(0xFF4338CA),
  ),
  violet(
    Color(0xFFA78BFA),
    Color(0xFF7C3AED),
    Color(0xFF2E1065),
    Color(0xFF5B21B6),
  ),
  fuchsia(
    Color(0xFFE879F9),
    Color(0xFFC026D3),
    Color(0xFF4A044E),
    Color(0xFFA21CAF),
  ),
  rose(
    Color(0xFFFB7185),
    Color(0xFFE11D48),
    Color(0xFF4C0519),
    Color(0xFFBE123C),
  ),
  red(
    Color(0xFFF87171),
    Color(0xFFDC2626),
    Color(0xFF450A0A),
    Color(0xFFB91C1C),
  ),
  orange(
    Color(0xFFFB923C),
    Color(0xFFEA580C),
    Color(0xFF431407),
    Color(0xFFC2410C),
  ),
  amber(
    Color(0xFFFBBF24),
    Color(0xFFF59E0B),
    Color(0xFF451A03),
    Color(0xFFB45309),
  ),
  lime(
    Color(0xFFA3E635),
    Color(0xFF65A30D),
    Color(0xFF1A2E05),
    Color(0xFF4D7C0F),
  ),
  green(
    Color(0xFF4ADE80),
    Color(0xFF16A34A),
    Color(0xFF052E16),
    Color(0xFF15803D),
  ),
  mint(
    Color(0xFF2DD4BF),
    Color(0xFF14B8A6),
    Color(0xFF042F2E),
    Color(0xFF0F766E),
  );

  const BrandAccent(this.fill, this.end, this.ink, this.readable);

  /// Bright fill on dark surfaces, and the light-theme container.
  final Color fill;

  /// Second stop of the play and seek gradients.
  final Color end;

  /// Dark glyph on [fill].
  final Color ink;

  /// Text and icons on the light canvas.
  final Color readable;

  static BrandAccent fromStorage(String? raw) {
    for (final accent in BrandAccent.values) {
      if (accent.name == raw) return accent;
    }
    return BrandAccent.cyan;
  }

  String get storageValue => name;

  /// Quiet label tint on dark surfaces. Cyan keeps the Pulse ice token.
  Color get labelTint {
    if (this == BrandAccent.cyan) return const Color(0xFFE0FDFF);
    return Color.lerp(fill, const Color(0xFFFFFFFF), 0.82)!;
  }
}

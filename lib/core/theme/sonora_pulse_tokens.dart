import 'package:material_ui/material_ui.dart';

/// Sonora Pulse color, type, radius, and spacing tokens.
///
/// Mapped from `docs/DESIGN.md` (Stitch design system Sonora Pulse).
/// Dark [ColorScheme] roles match the design-md surface/primary scale.
/// Light roles use the light canvas tokens with the same brand cyan.
class SonoraPulseTokens {
  const SonoraPulseTokens._();

  // ── Brand ────────────────────────────────────────────────────────────────

  static const Color gradientStart = Color(0xFF00F2FE);
  static const Color gradientEnd = Color(0xFF4FACFE);
  static const Color accentElectricBlue = Color(0xFF2563EB);
  static const Color accentIndigo = Color(0xFF4F46E5);
  static const Color accentVinylGroove = Color(0xFF11121A);

  /// Icon / glyph on brand gradient art (smart mixes, hero covers).
  static const Color onBrandGraphic = Color(0xFFFFFFFF);

  static const LinearGradient brandSpectrum = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientStart, gradientEnd],
  );

  static const LinearGradient brandSpectrumHorizontal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [gradientStart, gradientEnd],
  );

  /// 45° atmosphere used behind dark shells and the full player.
  static const LinearGradient darkAtmosphere = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [darkBgDeep, darkBgMid, darkBgElevated],
    stops: [0, 0.5, 1],
  );

  // ── Dark surfaces ────────────────────────────────────────────────────────

  static const Color surface = Color(0xFF101127);
  static const Color surfaceDim = Color(0xFF101127);
  static const Color surfaceBright = Color(0xFF36374F);
  static const Color surfaceContainerLowest = Color(0xFF0B0C22);
  static const Color surfaceContainerLow = Color(0xFF181930);
  static const Color surfaceContainer = Color(0xFF1D1E34);
  static const Color surfaceContainerHigh = Color(0xFF27283F);
  static const Color surfaceContainerHighest = Color(0xFF32334A);
  static const Color onSurface = Color(0xFFE1E0FF);
  static const Color onSurfaceVariant = Color(0xFFB9CACB);
  static const Color inverseSurface = Color(0xFFE1E0FF);
  static const Color inverseOnSurface = Color(0xFF2D2E46);
  static const Color outline = Color(0xFF849495);
  static const Color outlineVariant = Color(0xFF3A494B);
  static const Color surfaceTint = Color(0xFF00DCE6);

  static const Color primary = Color(0xFFE0FDFF);
  static const Color onPrimary = Color(0xFF00373A);
  static const Color primaryContainer = Color(0xFF00F2FE);
  static const Color onPrimaryContainer = Color(0xFF006A70);
  static const Color inversePrimary = Color(0xFF00696F);

  static const Color secondary = Color(0xFF9BCBFF);
  static const Color onSecondary = Color(0xFF003256);
  static const Color secondaryContainer = Color(0xFF3196E6);
  static const Color onSecondaryContainer = Color(0xFF002C4B);

  static const Color tertiary = Color(0xFFFAF6FF);
  static const Color onTertiary = Color(0xFF1D00A5);
  static const Color tertiaryContainer = Color(0xFFDAD7FF);
  static const Color onTertiaryContainer = Color(0xFF4F45E5);

  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  static const Color darkBgDeep = Color(0xFF0F1026);
  static const Color darkBgMid = Color(0xFF1A1B35);
  static const Color darkBgElevated = Color(0xFF2D2F54);
  static const Color darkSurface = Color(0xFF141527);
  static const Color darkSurfaceVariant = Color(0xFF1E2038);
  static const Color darkBorder = Color(0xFF2D2F54);

  // ── Light canvas ─────────────────────────────────────────────────────────

  static const Color lightBg = Color(0xFFF5F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEDF2F7);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightSurfaceHigh = Color(0xFFE2E8F0);
  static const Color lightSurfaceHighest = Color(0xFFD6DEE8);

  // ── Radii ────────────────────────────────────────────────────────────────

  /// Chips, search, and buttons (`full`).
  static const double radiusPill = 9999;

  /// Track rows and compact thumbs.
  static const double radiusSm = 12;

  /// Media cards and album tiles (`1.5rem`).
  static const double radiusMedia = 24;

  /// Dialogs stay slightly tighter than media cards.
  static const double radiusDialog = 20;

  // ── Spacing ──────────────────────────────────────────────────────────────

  static const double space2xs = 4;
  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;
  static const double space2xl = 48;

  static const double gutter = 20;
  static const double gutterDesktop = 24;
  static const double margin = 16;
  static const double marginDesktop = 32;

  /// Desktop / tablet mini-player shelf.
  static const double miniPlayerShelfHeight = 80;

  static BoxDecoration playControlDecoration({
    bool enabled = true,
    bool glow = true,
  }) {
    return BoxDecoration(
      shape: BoxShape.circle,
      gradient: enabled ? brandSpectrum : null,
      color: enabled ? null : primaryContainer.withValues(alpha: 0.38),
      boxShadow: !glow || !enabled
          ? null
          : [
              BoxShadow(
                color: gradientStart.withValues(alpha: 0.35),
                blurRadius: 18,
              ),
            ],
    );
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiary: tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outlineVariant,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: inverseSurface,
      onInverseSurface: inverseOnSurface,
      inversePrimary: inversePrimary,
      surfaceTint: surfaceTint,
      surfaceDim: surfaceDim,
      surfaceBright: surfaceBright,
      surfaceContainerLowest: surfaceContainerLowest,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
    );
  }

  /// Light studio canvas. Primary fill stays the brand cyan; readable
  /// text/icons use the darker inverse-primary teal.
  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: inversePrimary,
      onPrimary: lightSurface,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimary,
      secondary: accentElectricBlue,
      onSecondary: lightSurface,
      secondaryContainer: Color(0xFFD0E4FF),
      onSecondaryContainer: onSecondary,
      tertiary: accentIndigo,
      onTertiary: lightSurface,
      tertiaryContainer: Color(0xFFE2DFFF),
      onTertiaryContainer: onTertiary,
      error: Color(0xFFBA1A1A),
      onError: lightSurface,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: lightBg,
      onSurface: lightTextPrimary,
      onSurfaceVariant: lightTextSecondary,
      outline: outline,
      outlineVariant: lightBorder,
      shadow: Color(0xFF0F172A),
      scrim: Color(0xFF0F172A),
      inverseSurface: surface,
      onInverseSurface: onSurface,
      inversePrimary: primaryContainer,
      surfaceTint: surfaceTint,
      surfaceDim: lightSurfaceVariant,
      surfaceBright: lightSurface,
      surfaceContainerLowest: lightSurface,
      surfaceContainerLow: lightBg,
      surfaceContainer: lightSurfaceVariant,
      surfaceContainerHigh: lightSurfaceHigh,
      surfaceContainerHighest: lightSurfaceHighest,
    );
  }
}

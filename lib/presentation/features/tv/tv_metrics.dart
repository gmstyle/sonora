import 'package:material_ui/material_ui.dart';

/// Canvas colors for the standalone Android TV 10-foot experience.
///
/// Mirrors `sonora_atv_interactive_canvas.html` while keeping the active
/// Pulse [ColorScheme.primary] accent from user settings.
abstract final class TvColors {
  static const Color bg = Color(0xFF07090E);
  static const Color surface = Color(0xFF0E121B);
  static const Color surfaceCard = Color(0xFF151B27);
  static const Color surfaceButton = Color(0xFF1E293B);
  static const Color railBg = Color(0xF20A0D14);
  static const Color border = Color(0x1AFFFFFF);
  static const Color borderSubtle = Color(0x14FFFFFF);
  static const Color borderFaint = Color(0x0DFFFFFF);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
}

/// Applies the dark 10-foot TV surface palette on top of the active Pulse
/// [ThemeData], preserving [ColorScheme.primary] brand accent.
abstract final class TvTheme {
  static ThemeData apply(ThemeData base) {
    final scheme = base.colorScheme.copyWith(
      brightness: Brightness.dark,
      surface: TvColors.bg,
      surfaceDim: TvColors.bg,
      surfaceBright: TvColors.surfaceButton,
      surfaceContainerLowest: TvColors.bg,
      surfaceContainerLow: TvColors.surface,
      surfaceContainer: TvColors.surfaceCard,
      surfaceContainerHigh: TvColors.surfaceButton,
      surfaceContainerHighest: const Color(0xFF273244),
      onSurface: TvColors.textPrimary,
      onSurfaceVariant: TvColors.textSecondary,
      outlineVariant: TvColors.border,
    );

    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: TvColors.bg,
      focusColor: scheme.primary.withValues(alpha: 0.22),
      cardTheme: base.cardTheme.copyWith(color: TvColors.surfaceCard),
      dialogTheme: base.dialogTheme.copyWith(backgroundColor: TvColors.surface),
      dividerTheme: const DividerThemeData(color: TvColors.border),
      listTileTheme: ListTileThemeData(
        iconColor: TvColors.textSecondary,
        textColor: TvColors.textPrimary,
        tileColor: Colors.transparent,
        selectedColor: scheme.primary,
        selectedTileColor: scheme.primary.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Android TV layout tokens — standalone 10-foot product surface.
///
/// Design canvas is Material TV MDPI **960×540** (1px = 1dp). Sonora STBs with
/// density 320 on a 1080p override expose that logical size; tokens are authored
/// for it. Brand stays Pulse; anatomy follows Material TV / Leanback canons
/// (browser rows, left nav overlay, overscan), **not** phone shells or JetFit.
///
/// Spec: https://developer.android.com/design/ui/tv/guides/styles/layouts
abstract final class TvMetrics {
  static const double designWidth = 960;
  static const double designHeight = 540;

  /// Overscan-safe inset from screen edges (~5%).
  static const double overscanHorizontal = 48;
  static const double overscanVertical = 27;

  /// Collapsed left nav (icons). Content reserves this gutter always.
  static const double railCollapsedWidth = 72;

  /// Expanded left nav overlay (labels). Does not resize the content pane.
  static const double railExpandedWidth = 240;

  static const double railIconSize = 24;

  /// Padding inside the content pane (right edge ≈ overscan; left after rail).
  static const double contentPadding = 32;

  /// Browser-template shelf (vertical stack of horizontal rows).
  static const double shelfGap = 24;
  static const double shelfTitleGap = 10;

  /// Standard catalog poster card (1:1 artwork inside a framed dark card — 140dp per spec).
  static const double shelfCardWidth = 140;
  static const double shelfCardPadding = 10;
  static const double shelfCardImageSize =
      shelfCardWidth - (shelfCardPadding * 2);
  static const double shelfCardHeight = 140;
  static const double shelfCardTextHeight = 40;

  /// Framed poster height used by shelves and by [TvPosterGrid] alike.
  static const double posterCardHeight =
      shelfCardImageSize + shelfCardTextHeight + (shelfCardPadding * 2);
  static const double posterGridGap = 16;
  static const double shelfRowHeight = posterCardHeight + 32;

  /// Featured / resume items as a horizontal row of 16:9 framed cards.
  static const double featuredCardWidth = 220;
  static const double featuredCardImageHeight = 112;
  static const double featuredCardHeight = 178;
  static const double featuredRowHeight = featuredCardHeight + 24;

  /// Mood / genre horizontal pill cards.
  static const double categoryCardWidth = 216;
  static const double categoryCardHeight = 64;
  static const double categoryRowHeight = categoryCardHeight + 24;

  static const double focusScale = 1.08;
  static const double cardRadius = 12;

  /// Top hero spotlight banner height for contextual preview in Home.
  static const double heroSpotlightHeight = 175;

  static const Duration drawerAnimDuration = Duration(milliseconds: 200);

  /// Immersive entity header — under half the viewport so the track list peeks.
  static const double entityHeaderFraction = 0.40;

  /// Top padding for the first browse row (overscan-aware).
  static const double browseTopPadding = 24;
}

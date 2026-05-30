import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light({ColorScheme? dynamicColorScheme}) {
    final colorScheme =
        dynamicColorScheme ??
        ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        );

    // Se c'è un dynamicColorScheme (es. Monet su Android o Palette estrattive),
    // preserviamo intatti i suoi colori dinamici per non rovinare l'effetto tinta.
    // Se non c'è, applichiamo i nostri grigi alabastro premium come fallback neutro.
    final refinedColorScheme =
        dynamicColorScheme != null
            ? colorScheme
            : colorScheme.copyWith(
              surface: const Color(0xFFF8F9FA),
              surfaceContainerLowest: const Color(0xFFFFFFFF),
              surfaceContainerLow: const Color(0xFFF1F3F5),
              surfaceContainer: const Color(0xFFE9ECEF),
              surfaceContainerHigh: const Color(0xFFDEE2E6),
              surfaceContainerHighest: const Color(0xFFCED4DA),
            );

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: refinedColorScheme,
      scaffoldBackgroundColor: refinedColorScheme.surface,
    );

    final baseTextTheme = GoogleFonts.montserratTextTheme(baseTheme.textTheme);
    final customTextTheme = baseTextTheme.copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -1.0,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(fontWeight: FontWeight.w300),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w400,
      ),
    );

    return baseTheme.copyWith(
      textTheme: customTextTheme,
      // ── Slider Theme (Ultra-sottile, stile Spotify) ───────────────────────
      sliderTheme: SliderThemeData(
        trackHeight: 3.0,
        activeTrackColor: refinedColorScheme.primary,
        inactiveTrackColor: refinedColorScheme.primary.withValues(alpha: 0.15),
        thumbColor: refinedColorScheme.primary,
        overlayColor: refinedColorScheme.primary.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
        trackShape: const RectangularSliderTrackShape(),
      ),
      // ── AppBar Theme (Trasparente, simmetrica) ───────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      // ── Card Theme (Arrotondamento geometrico coerente) ─────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: refinedColorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // ── Dialog Theme (Elegante, arrotondato) ─────────────────────────────
      dialogTheme: DialogThemeData(
        elevation: 12,
        backgroundColor: refinedColorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      // ── Navigation Rail Theme ──────────────────────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: refinedColorScheme.surfaceContainerLow,
        indicatorColor: refinedColorScheme.primaryContainer.withValues(
          alpha: 0.5,
        ),
        selectedIconTheme: IconThemeData(color: refinedColorScheme.primary),
        unselectedIconTheme: IconThemeData(
          color: refinedColorScheme.onSurfaceVariant,
        ),
        selectedLabelTextStyle: GoogleFonts.montserrat(
          color: refinedColorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: GoogleFonts.montserrat(
          color: refinedColorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }

  static ThemeData dark({ColorScheme? dynamicColorScheme}) {
    final colorScheme =
        dynamicColorScheme ??
        ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        );

    // Stessa logica per il tema scuro: se c'è dynamicColorScheme lo preserviamo,
    // altrimenti andiamo di grigio carbonio scuro premium.
    final refinedColorScheme =
        dynamicColorScheme != null
            ? colorScheme
            : colorScheme.copyWith(
              surface: const Color(0xFF0F0F11),
              surfaceContainerLowest: const Color(0xFF000000),
              surfaceContainerLow: const Color(0xFF141417),
              surfaceContainer: const Color(0xFF1A1A1E),
              surfaceContainerHigh: const Color(0xFF222228),
              surfaceContainerHighest: const Color(0xFF2E2E36),
            );

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: refinedColorScheme,
      scaffoldBackgroundColor: refinedColorScheme.surface,
    );

    final baseTextTheme = GoogleFonts.montserratTextTheme(baseTheme.textTheme);
    final customTextTheme = baseTextTheme.copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -1.0,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(fontWeight: FontWeight.w300),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w400,
      ),
    );

    return baseTheme.copyWith(
      textTheme: customTextTheme,
      // ── Slider Theme (Ultra-sottile, stile Spotify) ───────────────────────
      sliderTheme: SliderThemeData(
        trackHeight: 3.0,
        activeTrackColor: refinedColorScheme.primary,
        inactiveTrackColor: refinedColorScheme.primary.withValues(alpha: 0.15),
        thumbColor: refinedColorScheme.primary,
        overlayColor: refinedColorScheme.primary.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
        trackShape: const RectangularSliderTrackShape(),
      ),
      // ── AppBar Theme (Trasparente, simmetrica) ───────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      // ── Card Theme (Arrotondamento geometrico coerente) ─────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: refinedColorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // ── Dialog Theme (Elegante, arrotondato) ─────────────────────────────
      dialogTheme: DialogThemeData(
        elevation: 12,
        backgroundColor: refinedColorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      // ── Navigation Rail Theme ──────────────────────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: refinedColorScheme.surfaceContainerLow,
        indicatorColor: refinedColorScheme.primaryContainer.withValues(
          alpha: 0.5,
        ),
        selectedIconTheme: IconThemeData(color: refinedColorScheme.primary),
        unselectedIconTheme: IconThemeData(
          color: refinedColorScheme.onSurfaceVariant,
        ),
        selectedLabelTextStyle: GoogleFonts.montserrat(
          color: refinedColorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: GoogleFonts.montserrat(
          color: refinedColorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }

  static ThemeData amoled({ColorScheme? dynamicColorScheme}) {
    final baseDark = dark(dynamicColorScheme: dynamicColorScheme);
    final amoledColorScheme = baseDark.colorScheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF101010),
      surfaceContainerHigh: const Color(0xFF1A1A1A),
      surfaceContainerHighest: const Color(0xFF222222),
    );

    return baseDark.copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: amoledColorScheme,
      // ── Slider Theme ───────────────────────────────────────────────────────
      sliderTheme: baseDark.sliderTheme.copyWith(
        activeTrackColor: amoledColorScheme.primary,
        inactiveTrackColor: amoledColorScheme.primary.withValues(alpha: 0.15),
        thumbColor: amoledColorScheme.primary,
        overlayColor: amoledColorScheme.primary.withValues(alpha: 0.12),
      ),
      // ── Card Theme ─────────────────────────────────────────────────────────
      cardTheme: baseDark.cardTheme.copyWith(
        color: amoledColorScheme.surfaceContainer,
      ),
      // ── Dialog Theme ───────────────────────────────────────────────────────
      dialogTheme: baseDark.dialogTheme.copyWith(
        backgroundColor: amoledColorScheme.surfaceContainerLow,
      ),
      // ── Navigation Rail Theme ──────────────────────────────────────────────
      navigationRailTheme: baseDark.navigationRailTheme.copyWith(
        backgroundColor: Colors.black,
        indicatorColor: amoledColorScheme.primaryContainer.withValues(
          alpha: 0.5,
        ),
        selectedIconTheme: IconThemeData(color: amoledColorScheme.primary),
        unselectedIconTheme: IconThemeData(
          color: amoledColorScheme.onSurfaceVariant,
        ),
        selectedLabelTextStyle: GoogleFonts.montserrat(
          color: amoledColorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: GoogleFonts.montserrat(
          color: amoledColorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }
}

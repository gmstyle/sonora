import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'player_colors.dart';
import 'sonora_pulse_tokens.dart';

/// Sonora Pulse [ThemeData] builders.
///
/// Dark [ColorScheme.primary] is brand cyan (`#00F2FE`) so Material filled
/// controls (FAB, Switch, [IconButton.filled], …) get a readable fill + dark
/// [ColorScheme.onPrimary] glyph. Ice label tint is
/// [SonoraPulseTokens.primaryTint] (TextButton / quiet accents). Brand fills
/// also use [SonoraPulseTokens.playControlDecoration] and
/// [SonoraPulseTokens.filledIconButtonStyle] when a widget style is required.
class AppTheme {
  static ThemeData light() => _build(SonoraPulseTokens.lightScheme());

  static ThemeData dark() => _build(SonoraPulseTokens.darkScheme());

  /// Pulse dark with the scaffold and base surface forced to
  /// [SonoraPulseTokens.surfaceContainerLowest].
  static ThemeData amoled() {
    final baseDark = dark();
    final scheme = baseDark.colorScheme.copyWith(
      surface: SonoraPulseTokens.surfaceContainerLowest,
      surfaceContainerLowest: SonoraPulseTokens.surfaceContainerLowest,
    );
    return baseDark.copyWith(
      scaffoldBackgroundColor: SonoraPulseTokens.surfaceContainerLowest,
      colorScheme: scheme,
      extensions: [PlayerColors.standard()],
      cardTheme: baseDark.cardTheme.copyWith(color: scheme.surfaceContainer),
      dialogTheme: baseDark.dialogTheme.copyWith(
        backgroundColor: scheme.surfaceContainerLow,
      ),
      navigationRailTheme: baseDark.navigationRailTheme.copyWith(
        backgroundColor: SonoraPulseTokens.surfaceContainerLowest,
      ),
      navigationBarTheme: baseDark.navigationBarTheme.copyWith(
        backgroundColor: SonoraPulseTokens.surfaceContainerLowest,
      ),
    );
  }

  static ThemeData _build(ColorScheme scheme) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );

    final textTheme = _textTheme(baseTheme.textTheme, scheme);
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SonoraPulseTokens.radiusPill),
    );
    final isDark = scheme.brightness == Brightness.dark;
    final labelAccent = isDark ? SonoraPulseTokens.primaryTint : scheme.primary;
    final brandFill = scheme.primaryContainer;
    final brandOnFill = SonoraPulseTokens.onPrimary;

    return baseTheme.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [PlayerColors.standard()],
      splashFactory: InkSparkle.splashFactory,
      // Same sentinel Material uses so [IconButton.filled] keeps
      // [ColorScheme.onPrimary] instead of a non-default light IconTheme color.
      iconTheme: IconThemeData(
        color: isDark ? kDefaultIconLightColor : kDefaultIconDarkColor,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: brandFill,
        inactiveTrackColor: brandFill.withValues(alpha: 0.22),
        thumbColor: brandFill,
        overlayColor: brandFill.withValues(alpha: 0.16),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brandFill,
        linearTrackColor: brandFill.withValues(alpha: 0.22),
        circularTrackColor: brandFill.withValues(alpha: 0.22),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsIconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SonoraPulseTokens.radiusMedia),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 8,
        backgroundColor: isDark
            ? SonoraPulseTokens.darkSurfaceVariant
            : SonoraPulseTokens.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SonoraPulseTokens.radiusDialog),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: brandFill.withValues(alpha: 0.28),
        disabledColor: scheme.surfaceContainer.withValues(alpha: 0.5),
        checkmarkColor: brandOnFill,
        labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: pill,
        side: BorderSide(color: scheme.outlineVariant),
        showCheckmark: false,
      ),
      // Colors come from ColorScheme: filled → primary/onPrimary (brand),
      // tonal → secondaryContainer/onSecondaryContainer. Do not set
      // backgroundColor/foregroundColor here — FilledButtonTheme applies to
      // both variants and would turn Follow/Like tonal pills into brand fills
      // (then activeColor: primary washes out on the same cyan).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: pill,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: pill,
          backgroundColor: brandFill,
          foregroundColor: brandOnFill,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: brandFill,
        foregroundColor: brandOnFill,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: pill,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: pill,
          foregroundColor: labelAccent,
          textStyle: textTheme.labelLarge,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return brandOnFill;
          }
          return scheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.selected)) {
            return brandFill;
          }
          return scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return scheme.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.selected)) {
            return brandFill;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(brandOnFill),
        side: BorderSide(color: scheme.outline, width: 2),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          if (states.contains(WidgetState.selected)) {
            return brandFill;
          }
          return scheme.outline;
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: brandFill.withValues(alpha: 0.28),
        selectedIconTheme: IconThemeData(
          color: isDark ? brandFill : scheme.primary,
        ),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: isDark ? brandFill : scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: brandFill.withValues(alpha: 0.28),
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected
                ? (isDark ? brandFill : scheme.primary)
                : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? (isDark ? brandFill : scheme.primary)
                : scheme.onSurfaceVariant,
          );
        }),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    final jakarta = GoogleFonts.plusJakartaSansTextTheme(base);
    return jakarta.copyWith(
      displayLarge: jakarta.displayLarge?.copyWith(
        fontSize: 40,
        height: 48 / 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: scheme.onSurface,
      ),
      displayMedium: jakarta.displayMedium?.copyWith(
        fontSize: 30,
        height: 38 / 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.45,
        color: scheme.onSurface,
      ),
      headlineLarge: jakarta.headlineLarge?.copyWith(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.28,
        color: scheme.onSurface,
      ),
      headlineMedium: jakarta.headlineMedium?.copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.22,
        color: scheme.onSurface,
      ),
      headlineSmall: jakarta.headlineSmall?.copyWith(
        fontSize: 20,
        height: 26 / 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
        color: scheme.onSurface,
      ),
      titleLarge: jakarta.titleLarge?.copyWith(
        fontSize: 17,
        height: 22 / 17,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: jakarta.titleMedium?.copyWith(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleSmall: jakarta.titleSmall?.copyWith(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: jakarta.bodyLarge?.copyWith(
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
      bodyMedium: jakarta.bodyMedium?.copyWith(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
      bodySmall: jakarta.bodySmall?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w400,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: jakarta.labelLarge?.copyWith(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.13,
        color: scheme.onSurface,
      ),
      labelMedium: jakarta.labelMedium?.copyWith(
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.22,
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: jakarta.labelSmall?.copyWith(
        fontSize: 10,
        height: 12 / 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

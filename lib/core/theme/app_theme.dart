import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light({ColorScheme? dynamicColorScheme}) {
    final colorScheme =
        dynamicColorScheme ??
        ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
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

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }

  static ThemeData amoled({ColorScheme? dynamicColorScheme}) {
    final baseDark = dark(dynamicColorScheme: dynamicColorScheme);
    return baseDark.copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: baseDark.colorScheme.copyWith(
        surface: Colors.black,
        // In un tema AMOLED, vogliamo che i surfaceContainer si fondano
        // in modo uniforme col display, indipendentemente dal seed dinamico
        surfaceContainerLowest: Colors.black,
        surfaceContainerLow: const Color(0xFF0A0A0A),
        surfaceContainer: const Color(0xFF101010),
        surfaceContainerHigh: const Color(0xFF1A1A1A),
        surfaceContainerHighest: const Color(0xFF222222),
      ),
      appBarTheme: baseDark.appBarTheme.copyWith(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: baseDark.bottomNavigationBarTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      navigationRailTheme: baseDark.navigationRailTheme.copyWith(
        backgroundColor: Colors.black,
      ),
    );
  }
}

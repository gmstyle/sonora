import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light({ColorScheme? dynamicColorScheme}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: dynamicColorScheme ??
          ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.light,
          ),
    );
  }

  static ThemeData dark({ColorScheme? dynamicColorScheme}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: dynamicColorScheme ??
          ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
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
    );
  }
}

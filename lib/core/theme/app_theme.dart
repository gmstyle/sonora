import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light({bool dynamicColor = false}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme:
          dynamicColor
              ? ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.light,
              )
              : const ColorScheme.light(),
    );
  }

  static ThemeData dark({bool dynamicColor = false}) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme:
          dynamicColor
              ? ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.dark,
              )
              : const ColorScheme.dark(),
    );
  }

  static ThemeData amoled() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        surface: Colors.black,
      ),
    );
  }
}

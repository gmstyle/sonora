import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
    );
  }

  static ThemeData amoled() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: ColorScheme.dark(
        surface: Colors.black,
        primaryContainer: Colors.grey.shade900,
        secondaryContainer: Colors.grey.shade900,
      ),
    );
  }
}

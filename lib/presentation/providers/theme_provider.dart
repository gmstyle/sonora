import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'settings_provider.dart';

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).themeMode;
});

final lightThemeProvider = Provider.family<ThemeData, ColorScheme?>((ref, dynamicScheme) {
  final settings = ref.watch(settingsProvider);
  return AppTheme.light(
    dynamicColorScheme: settings.useDynamicColor ? dynamicScheme : null,
  );
});

final darkThemeProvider = Provider.family<ThemeData, ColorScheme?>((ref, dynamicScheme) {
  final settings = ref.watch(settingsProvider);
  if (settings.useAmoled) {
    return AppTheme.amoled(
      dynamicColorScheme: settings.useDynamicColor ? dynamicScheme : null,
    );
  }
  return AppTheme.dark(
    dynamicColorScheme: settings.useDynamicColor ? dynamicScheme : null,
  );
});

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'settings_provider.dart';

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).themeMode;
});

final lightThemeProvider = Provider<ThemeData>((ref) => AppTheme.light());

final darkThemeProvider = Provider<ThemeData>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings.useAmoled) return AppTheme.amoled();
  return AppTheme.dark();
});

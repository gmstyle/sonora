import 'dart:io';

import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

/// Pure visibility rule for the proactive battery-optimization prompt.
///
/// Returns `true` only when all of the following hold:
/// - running on Android
/// - the user has not opted out permanently
/// - system battery optimization is still active (`isBatteryOptimizationDisabled == false`)
bool shouldShowBatteryPrompt({
  required bool isAndroid,
  required bool dismissedForever,
  required bool? isBatteryOptimizationDisabled,
}) {
  if (!isAndroid) return false;
  if (dismissedForever) return false;
  // Treat null as "unknown / assume already OK" (same convention as
  // [batteryOptimizationProvider]) so a plugin failure does not spam the user.
  return isBatteryOptimizationDisabled == false;
}

/// Evaluated once per provider lifetime (typically once per app start).
/// Returns whether the startup battery-optimization prompt should be shown.
final shouldShowBatteryPromptProvider = FutureProvider<bool>((ref) async {
  if (!Platform.isAndroid) return false;

  final prefs = ref.read(sharedPreferencesProvider);
  final dismissed = prefs.getBool(kBatteryPromptDismissedKey) ?? false;
  if (dismissed) return false;

  final disabled =
      await DisableBatteryOptimization.isBatteryOptimizationDisabled;
  return shouldShowBatteryPrompt(
    isAndroid: true,
    dismissedForever: false,
    isBatteryOptimizationDisabled: disabled,
  );
});

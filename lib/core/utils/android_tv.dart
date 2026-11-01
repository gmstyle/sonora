import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Detects Android TV / Leanback / remote-only boxes via MainActivity.
///
/// Combines uiMode, leanback features, `ro.build.characteristics=tv`, and
/// missing touchscreen — hybrid STBs often omit FEATURE_LEANBACK alone.
class AndroidTv {
  static const _channel = MethodChannel('com.gmstyle.sonora/android_tv');

  /// Whether the current device should use the TV shell.
  ///
  /// Returns `false` off Android and on any channel failure.
  static Future<bool> isAndroidTv() async {
    if (!Platform.isAndroid) return false;
    try {
      final value = await _channel.invokeMethod<bool>('isAndroidTv');
      return value ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Native detection signals for debug logs.
  static Future<Map<String, Object?>> diagnostics() async {
    if (!Platform.isAndroid) return const {};
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'tvDiagnostics',
      );
      if (raw == null) return const {};
      return raw.map((key, value) => MapEntry(key.toString(), value));
    } on PlatformException {
      return const {};
    } on MissingPluginException {
      return const {};
    }
  }

  /// Logs [diagnostics] once at startup (debug builds only).
  static Future<void> debugLogDetection() async {
    if (!kDebugMode || !Platform.isAndroid) return;
    final info = await diagnostics();
    debugPrint('[AndroidTv] detection=$info');
  }
}

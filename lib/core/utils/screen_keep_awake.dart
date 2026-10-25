import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the display awake while a screen needs continuous visibility.
///
/// Android only: sets [WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON]
/// via [WakelockPlus]. No-op on Linux and other platforms.
class ScreenKeepAwake {
  ScreenKeepAwake._();

  static Future<void> enable() async {
    if (!Platform.isAndroid) return;
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('ScreenKeepAwake.enable failed: $e');
    }
  }

  static Future<void> disable() async {
    if (!Platform.isAndroid) return;
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('ScreenKeepAwake.disable failed: $e');
    }
  }
}

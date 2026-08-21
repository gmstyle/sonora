import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android battery-optimization helpers.
///
/// The AOSP ignore-battery-optimizations flow uses [permission_handler].
/// OEM-specific settings (Xiaomi, Huawei, Samsung, …) are opened through a
/// small MethodChannel in [MainActivity].
class AndroidBattery {
  static const _channel = MethodChannel('com.gmstyle.sonora/battery');

  static Future<bool> isOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  static Future<void> requestDisableOptimization() async {
    if (!Platform.isAndroid) return;
    await Permission.ignoreBatteryOptimizations.request();
  }

  static Future<void> openManufacturerSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openManufacturerBatterySettings');
  }

  static Future<void> openBluetoothSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('openBluetoothSettings');
  }
}

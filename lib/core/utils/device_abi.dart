import 'dart:io';

import 'package:flutter/services.dart';

/// Reports the device CPU architectures, so the in-app updater can pick the
/// matching APK from a per-ABI release.
///
/// Backed by `Build.SUPPORTED_ABIS` through a MethodChannel in `MainActivity`,
/// rather than a dependency such as `device_info_plus`, since this is the only
/// device fact Sonora needs.
class DeviceAbi {
  static const _channel = MethodChannel('com.gmstyle.sonora/device_abi');

  /// Supported ABIs, most-preferred first.
  ///
  /// Returns an empty list off Android, and on any channel failure: callers
  /// treat that as "unknown" and fall back to the first APK in the release.
  static Future<List<String>> getSupportedAbis() async {
    if (!Platform.isAndroid) return const [];
    try {
      final abis = await _channel.invokeListMethod<String>('getSupportedAbis');
      return abis ?? const [];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }
}

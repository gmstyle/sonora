import 'dart:io';

import 'package:flutter/services.dart';

class ApkInstaller {
  static const MethodChannel _channel =
      MethodChannel('com.gmstyle.sonora/apk_installer');

  static Future<void> installApk(String filePath) async {
    if (!Platform.isAndroid) {
      throw PlatformException(
        code: 'UNSUPPORTED',
        message: 'APK installation is only supported on Android',
      );
    }

    await _channel.invokeMethod<void>('installApk', {
      'filePath': filePath,
    });
  }
}
import 'package:flutter/services.dart';

/// Reads the Android WebView [CookieManager] (includes httpOnly cookies).
class WebViewCookieReader {
  static const _channel = MethodChannel('com.gmstyle.sonora/webview_cookies');

  /// `name=value; …` for [url], or null when unavailable (non-Android).
  static Future<String?> getCookie(String url) async {
    try {
      final raw = await _channel.invokeMethod<String>('getCookie', {
        'url': url,
      });
      return raw;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> clearCookies() async {
    try {
      await _channel.invokeMethod<void>('clearCookies');
    } on MissingPluginException {
      // no-op
    } on PlatformException {
      // no-op
    }
  }

  /// Default Android WebView User-Agent, or null when unavailable.
  static Future<String?> getDefaultUserAgent() async {
    try {
      return await _channel.invokeMethod<String>('getDefaultUserAgent');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

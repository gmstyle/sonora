import 'dart:io';

import 'package:youtube_explode_dart/js_challenge.dart';
import 'package:youtube_explode_dart/solvers.dart';
import 'package:youtube_explode_webview/youtube_explode_webview.dart';

/// Creates the platform-appropriate [BaseWebJsRunner] for BotGuard PO token
/// minting and `n`/`sig` JS challenge solving, or `null` if unavailable.
Future<BaseWebJsRunner?> createPlatformJsRunner() async {
  if (Platform.isAndroid) {
    return WebViewJsRunner();
  }
  if (Platform.isLinux) {
    return ChromiumCdpJsRunner.tryCreate();
  }
  return null;
}

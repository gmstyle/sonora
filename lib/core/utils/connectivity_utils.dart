import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityUtils {
  /// Performs a quick active DNS lookup ping (1.5 seconds) to determine if
  /// internet is actually reachable and functional.
  static Future<bool> isOffline() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.isEmpty ||
          (results.length == 1 && results.contains(ConnectivityResult.none))) {
        return true;
      }
      final address = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(milliseconds: 1500));
      return address.isEmpty || address.first.rawAddress.isEmpty;
    } catch (_) {
      return true; // Fallback: assume offline on error or timeout
    }
  }

  static Future<bool> isOnline() async {
    return !await isOffline();
  }
}

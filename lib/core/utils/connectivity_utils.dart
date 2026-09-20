import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Shared connectivity helpers.
///
/// **UI offline** ([connectivity_provider]): interface presence only via
/// [connectivity] / [onConnectivityChanged].
/// **Playback fail-fast**: [isOffline] / [isOnline] also probe DNS so captive
/// portals are treated as offline for streaming.
class ConnectivityUtils {
  ConnectivityUtils._();

  /// Single app-wide [Connectivity] instance (UI + player + DNS pre-check).
  static final Connectivity connectivity = Connectivity();

  /// Interface + DNS reachability check (1.5s timeout to `google.com`).
  static Future<bool> isOffline() async {
    try {
      final results = await connectivity.checkConnectivity();
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

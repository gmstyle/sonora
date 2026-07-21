import 'dart:io';

/// Utility for checking whether a stream URL is still usable for playback.
///
/// YouTube stream URLs contain an `expire` Unix timestamp query parameter.
/// Local file URIs are valid only if the file still exists on disk.
abstract final class UrlStaleness {
  /// Returns `true` if [url] is expired, missing, or unusable.
  ///
  /// - `null` or empty → stale
  /// - `file://` → stale if the file no longer exists on disk
  /// - `http(s)://` → stale if the `expire` query param is absent or in the past,
  ///   or if [lastPauseTimestamp] indicates the app was paused for longer than [maxIdleDuration].
  static bool isStale(
    String? url, {
    DateTime? lastPauseTimestamp,
    Duration maxIdleDuration = const Duration(minutes: 15),
  }) {
    if (url == null || url.isEmpty) return true;
    if (url.startsWith('file://')) {
      return !File.fromUri(Uri.parse(url)).existsSync();
    }
    if (lastPauseTimestamp != null &&
        DateTime.now().difference(lastPauseTimestamp) > maxIdleDuration) {
      return true;
    }
    final expireParam = Uri.tryParse(url)?.queryParameters['expire'];
    if (expireParam == null) return true;
    final expireTs = int.tryParse(expireParam);
    if (expireTs == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 > expireTs;
  }
}

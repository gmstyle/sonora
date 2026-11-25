import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Shared client classification and header policy for YouTube Innertube and
/// `googlevideo.com` CDN requests.
class YoutubeClientPolicy {
  YoutubeClientPolicy._();

  static const String defaultBrowserUserAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/148.0.0.0 Safari/537.36';

  /// Clients that authenticate via device/app identity rather than browser
  /// cookies. Sending web login cookies or `SAPISIDHASH` to these clients
  /// triggers YouTube's bot/login checks.
  static const Set<String> cookielessClients = <String>{
    'VISIONOS',
    'ANDROID_VR',
    'IOS',
    'ANDROID',
    'ANDROID_MUSIC',
    'TVHTML5_SIMPLY',
  };

  /// Returns `true` when [clientName] must not receive browser cookies,
  /// `X-Goog-Visitor-Id`, or `Authorization: SAPISIDHASH`.
  static bool isCookielessClient(String? clientName) {
    if (clientName == null) return false;
    final normalized = clientName.trim().toUpperCase();
    return normalized.isNotEmpty && cookielessClients.contains(normalized);
  }

  /// Extracts the normalized Innertube client name from a `googlevideo.com`
  /// stream URL (`?c=...`).
  static String? streamClientName(Uri uri) {
    final value = uri.queryParameters['c']?.trim().toUpperCase();
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Returns `true` when `.youtube.com` cookies should be attached to a
  /// `googlevideo.com` stream GET for [uri].
  static bool shouldAttachCookiesForStreamUrl(Uri uri) {
    return !isCookielessClient(streamClientName(uri));
  }

  /// Returns the `User-Agent` matching the `c=` parameter of [uri], falling
  /// back to [defaultBrowserUserAgent].
  static String userAgentForStreamUrl(Uri uri) {
    final name = streamClientName(uri);
    final ua = YoutubeApiClient.userAgentForClientName(name);
    if (ua != null && ua.isNotEmpty) return ua;
    return defaultBrowserUserAgent;
  }
}

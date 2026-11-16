import 'dart:convert';
import 'dart:io';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:path/path.dart' as p;

/// On-disk YouTube session (auth cookies + optional account card).
/// Device-local — never in backup.
class YoutubeSessionStore {
  YoutubeSessionStore(this.file);

  /// Default path beside the app support / CLI database directory.
  factory YoutubeSessionStore.inDirectory(String directory) {
    return YoutubeSessionStore(File(p.join(directory, 'youtube_session.json')));
  }

  final File file;

  static const _version = 2;

  /// Loads cookies into [YTMusic]'s jar. No-op when the file is missing.
  Future<void> loadInto(YTMusic ytmusic) async {
    if (!await file.exists()) return;
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      final list = raw['cookies'];
      if (list is! List) return;
      final cookies = <Cookie>[];
      for (final entry in list) {
        if (entry is! Map) continue;
        final name = entry['name']?.toString();
        final value = entry['value']?.toString();
        if (name == null || value == null || name.isEmpty) continue;
        if (!isYoutubeSessionCookieName(name)) continue;
        try {
          cookies.add(Cookie(name, value)..domain = '.youtube.com');
        } catch (_) {}
      }
      if (cookies.isEmpty) return;
      await applyAuthCookies(ytmusic.cookieJar, cookies);
    } catch (_) {
      // Corrupt session file: stay guest.
    }
  }

  /// Persists auth cookies currently in [ytmusic]'s jar.
  Future<void> saveFrom(YTMusic ytmusic) async {
    final www = await loadCookieMap(ytmusic.cookieJar, kYoutubeOrigin);
    final music = await loadCookieMap(ytmusic.cookieJar, kMusicOrigin);
    final merged = <String, String>{...www, ...music};
    // Preserve SID/SAPISID family from disk if the live jar lost them to a
    // Set-Cookie wipe but still looks signed-in via __Secure-3*.
    Map<String, dynamic>? existingAccount;
    if (await file.exists()) {
      try {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map) {
          if (raw['account'] is Map) {
            existingAccount = Map<String, dynamic>.from(raw['account'] as Map);
          }
          if (raw['cookies'] is List) {
            for (final entry in raw['cookies'] as List) {
              if (entry is! Map) continue;
              final name = entry['name']?.toString();
              final value = entry['value']?.toString();
              if (name == null || value == null || value.isEmpty) continue;
              if (!kYtSessionMirrorCookieNames.contains(name)) continue;
              merged.putIfAbsent(name, () => value);
            }
          }
        }
      } catch (_) {}
    }
    if (!jarHasAuth(merged)) {
      await clear();
      return;
    }
    final cookies = merged.entries
        .where((e) => isYoutubeSessionCookieName(e.key) && e.value.isNotEmpty)
        .map((e) => {'name': e.key, 'value': e.value})
        .toList();
    await _write(cookies: cookies, account: existingAccount);
  }

  /// Caches the account card shown in Settings (name / email / handle / photo).
  Future<void> saveAccount(AccountInfo info) async {
    List<Map<String, String>> cookies = const [];
    if (await file.exists()) {
      try {
        final raw = jsonDecode(await file.readAsString());
        if (raw is Map && raw['cookies'] is List) {
          cookies = (raw['cookies'] as List)
              .whereType<Map>()
              .map(
                (e) => {
                  'name': e['name']?.toString() ?? '',
                  'value': e['value']?.toString() ?? '',
                },
              )
              .where((e) => e['name']!.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    if (cookies.isEmpty) return;
    await _write(cookies: cookies, account: info.toMap());
  }

  /// Last cached account card, or null.
  Future<AccountInfo?> loadAccount() async {
    if (!await file.exists()) return null;
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map || raw['account'] is! Map) return null;
      return AccountInfo.fromMap(
        Map<String, dynamic>.from(raw['account'] as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _write({
    required List<Map<String, String>> cookies,
    Map<String, dynamic>? account,
  }) async {
    await file.parent.create(recursive: true);
    final payload = <String, dynamic>{
      'version': _version,
      'cookies': cookies,
      'account': ?account,
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }
}

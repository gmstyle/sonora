import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show Hmac, sha256;
import 'package:cryptography/cryptography.dart' hide Hmac;
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

/// QR / LAN handoff of a YouTube session (phone → TV or Linux).
///
/// Payload: `sonora-link:1:<ip>:<port>:<keyBase64Url>`
class DeviceLinkOffer {
  DeviceLinkOffer({required this.ip, required this.port, required this.key});

  static const prefix = 'sonora-link:1:';
  static const keyLength = 32;
  static const ttl = Duration(minutes: 3);

  final String ip;
  final int port;
  final Uint8List key;

  static DeviceLinkOffer create({required String ip, required int port}) {
    final key = Uint8List(keyLength);
    final random = Random.secure();
    for (var i = 0; i < key.length; i++) {
      key[i] = random.nextInt(256);
    }
    return DeviceLinkOffer(ip: ip, port: port, key: key);
  }

  String get qrPayload =>
      '$prefix$ip:$port:${base64Url.encode(key).replaceAll('=', '')}';

  /// Six digits both screens show so the user can confirm the pair.
  String get confirmationCode {
    final digest = Hmac(sha256, key).convert(utf8.encode('sas')).bytes;
    final number =
        ByteData.sublistView(Uint8List.fromList(digest)).getUint32(0) % 1000000;
    final digits = number.toString().padLeft(6, '0');
    return '${digits.substring(0, 3)}\u{a0}${digits.substring(3)}';
  }

  static DeviceLinkOffer? parseQr(String raw) {
    final text = raw.trim();
    if (!text.startsWith(prefix)) return null;
    final rest = text.substring(prefix.length);
    final parts = rest.split(':');
    if (parts.length < 3) return null;
    final keyB64 = parts.last;
    final portStr = parts[parts.length - 2];
    final ip = parts.sublist(0, parts.length - 2).join(':');
    final port = int.tryParse(portStr);
    if (port == null || port <= 0 || port > 65535) return null;
    if (ip.isEmpty) return null;
    try {
      final pad = (4 - keyB64.length % 4) % 4;
      final padded = keyB64 + ('=' * pad);
      final key = base64Url.decode(padded);
      if (key.length != keyLength) return null;
      return DeviceLinkOffer(ip: ip, port: port, key: Uint8List.fromList(key));
    } catch (_) {
      return null;
    }
  }
}

/// Cookies (+ optional account card) sealed for the one-shot LAN POST.
class DeviceLinkSession {
  const DeviceLinkSession({required this.cookies, this.account});

  final Map<String, String> cookies;
  final AccountInfo? account;

  bool get isEmpty => cookies.isEmpty;
}

/// AES-GCM sealed cookie payload for the one-shot LAN POST.
class DeviceLinkCrypto {
  DeviceLinkCrypto(this.key);

  final Uint8List key;
  static final _algo = AesGcm.with256bits();

  Future<Uint8List> seal(
    Map<String, String> cookies, {
    AccountInfo? account,
  }) async {
    final payload = <String, dynamic>{
      'cookies': cookies,
      if (account != null) 'account': account.toMap(),
    };
    final plain = utf8.encode(jsonEncode(payload));
    final secretKey = SecretKey(key);
    final box = await _algo.encrypt(plain, secretKey: secretKey);
    return Uint8List.fromList([
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  Future<DeviceLinkSession?> open(Uint8List blob) async {
    if (blob.length < 28) return null;
    try {
      final nonce = blob.sublist(0, 12);
      final mac = blob.sublist(blob.length - 16);
      final cipherText = blob.sublist(12, blob.length - 16);
      final secretKey = SecretKey(key);
      final clear = await _algo.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: secretKey,
      );
      final raw = jsonDecode(utf8.decode(clear));
      if (raw is! Map) return null;
      final cookiesRaw = raw['cookies'];
      if (cookiesRaw is! Map) return null;
      final cookies = <String, String>{
        for (final e in cookiesRaw.entries)
          e.key.toString(): e.value.toString(),
      };
      if (cookies.isEmpty) return null;
      AccountInfo? account;
      final accountRaw = raw['account'];
      if (accountRaw is Map) {
        account = AccountInfo.fromMap(Map<String, dynamic>.from(accountRaw));
      }
      return DeviceLinkSession(cookies: cookies, account: account);
    } catch (_) {
      return null;
    }
  }
}

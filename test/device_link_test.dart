import 'dart:typed_data';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/services/device_link.dart';

void main() {
  group('DeviceLinkOffer', () {
    test('round-trips qr payload', () {
      final offer = DeviceLinkOffer.create(ip: '192.168.1.10', port: 41234);
      final parsed = DeviceLinkOffer.parseQr(offer.qrPayload);
      expect(parsed, isNotNull);
      expect(parsed!.ip, '192.168.1.10');
      expect(parsed.port, 41234);
      expect(parsed.key, offer.key);
    });

    test('confirmation code is six digits with nbsp', () {
      final offer = DeviceLinkOffer(
        ip: '10.0.0.2',
        port: 1,
        key: Uint8List.fromList(List.filled(32, 7)),
      );
      final code = offer.confirmationCode;
      expect(code.contains('\u{a0}'), isTrue);
      expect(code.replaceAll('\u{a0}', '').length, 6);
      expect(int.tryParse(code.replaceAll('\u{a0}', '')), isNotNull);
    });

    test('rejects bad prefix', () {
      expect(DeviceLinkOffer.parseQr('ymusic-link:2:x'), isNull);
    });
  });

  group('DeviceLinkCrypto', () {
    test('seal and open round-trip cookies', () async {
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final crypto = DeviceLinkCrypto(key);
      final sealed = await crypto.seal({'SAPISID': 'abc', 'SOCS': 'CAI'});
      final opened = await crypto.open(sealed);
      expect(opened?.cookies, {'SAPISID': 'abc', 'SOCS': 'CAI'});
      expect(opened?.account, isNull);
    });

    test('seal and open round-trip account card', () async {
      final key = Uint8List.fromList(List.generate(32, (i) => i + 3));
      final crypto = DeviceLinkCrypto(key);
      final sealed = await crypto.seal({
        'SAPISID': 'abc',
      }, account: AccountInfo(name: 'Gabriele', email: 'g@example.com'));
      final opened = await crypto.open(sealed);
      expect(opened?.cookies, {'SAPISID': 'abc'});
      expect(opened?.account?.name, 'Gabriele');
      expect(opened?.account?.email, 'g@example.com');
    });

    test('wrong key fails open', () async {
      final sealed = await DeviceLinkCrypto(
        Uint8List.fromList(List.filled(32, 1)),
      ).seal({'SAPISID': 'x'});
      final opened = await DeviceLinkCrypto(
        Uint8List.fromList(List.filled(32, 2)),
      ).open(sealed);
      expect(opened, isNull);
    });
  });
}

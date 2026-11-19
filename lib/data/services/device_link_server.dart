import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'device_link.dart';

/// One-shot LAN receiver for an encrypted YouTube session from the phone.
class DeviceLinkServer {
  HttpServer? _server;
  DeviceLinkOffer? _offer;
  Timer? _ttl;

  DeviceLinkOffer? get offer => _offer;

  bool get isListening => _server != null;

  /// Binds an ephemeral port on [ip] (private IPv4). Completes once with session.
  Future<(DeviceLinkOffer, Future<DeviceLinkSession>)> start(String ip) async {
    await stop();
    final completer = Completer<DeviceLinkSession>();

    late final DeviceLinkOffer offer;
    Future<Response> handler(Request request) async {
      if (request.method != 'POST' || request.url.path != 'session') {
        return Response.notFound('not found');
      }
      final body = await request.read().fold<BytesBuilder>(
        BytesBuilder(copy: false),
        (b, chunk) => b..add(chunk),
      );
      final session = await DeviceLinkCrypto(offer.key).open(body.takeBytes());
      if (session == null || session.isEmpty) {
        return Response(400, body: 'bad payload');
      }
      if (!completer.isCompleted) {
        completer.complete(session);
      }
      // Close only after the 200 has left the socket. Stopping here with
      // force:true resets the phone mid-response and looks like a Wi-Fi failure
      // even though Linux already applied the session.
      scheduleMicrotask(() async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await stop();
      });
      return Response.ok(
        'ok',
        headers: const {'Content-Type': 'text/plain; charset=utf-8'},
      );
    }

    final server = await shelf_io.serve(handler, ip, 0);
    _server = server;
    offer = DeviceLinkOffer.create(ip: ip, port: server.port);
    _offer = offer;

    _ttl = Timer(DeviceLinkOffer.ttl, () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('device link timed out'));
      }
      unawaited(stop());
    });

    return (offer, completer.future);
  }

  Future<void> stop() async {
    _ttl?.cancel();
    _ttl = null;
    _offer = null;
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: false);
    }
  }
}

bool _isVirtualInterface(String name) {
  final lower = name.toLowerCase();
  return lower == 'lo' ||
      lower.startsWith('docker') ||
      lower.startsWith('br-') ||
      lower.startsWith('virbr') ||
      lower.startsWith('veth') ||
      lower.startsWith('tailscale') ||
      lower.startsWith('tun') ||
      lower.startsWith('tap');
}

bool _isPreferredLanInterface(String name) {
  final lower = name.toLowerCase();
  return lower.contains('wlan') ||
      lower.contains('wifi') ||
      lower.contains('wl') ||
      lower.startsWith('wlp') ||
      lower.startsWith('enp') ||
      lower.startsWith('eth') ||
      lower == 'en0';
}

bool _isPrivateIpv4(String ip) {
  return ip.startsWith('10.') ||
      ip.startsWith('192.168.') ||
      RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.').hasMatch(ip);
}

/// Best private IPv4 for the QR (skips loopback and virtual bridges).
Future<String?> localLanIpv4() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    String? otherPrivate;
    String? otherNonLoopback;
    String? virtualPrivate;
    for (final iface in interfaces) {
      final virtual = _isVirtualInterface(iface.name);
      final preferred = !virtual && _isPreferredLanInterface(iface.name);
      for (final addr in iface.addresses) {
        if (addr.isLoopback) continue;
        final ip = addr.address;
        final isPrivate = _isPrivateIpv4(ip);
        if (preferred && isPrivate) return ip;
        if (!virtual) {
          if (isPrivate) {
            otherPrivate ??= ip;
          } else {
            otherNonLoopback ??= ip;
          }
        } else if (isPrivate) {
          virtualPrivate ??= ip;
        }
      }
    }
    return otherPrivate ?? otherNonLoopback ?? virtualPrivate;
  } catch (_) {}
  return null;
}

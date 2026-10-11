import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../link/sonora_link.dart';

/// First argv entry that looks like a `sonora://` URI, if any.
String? extractSonoraUriFromArgs(List<String> args) {
  for (final arg in args) {
    final trimmed = arg.trim();
    if (trimmed.isEmpty) continue;
    if (parseSonoraLink(trimmed) != null) return trimmed;
  }
  return null;
}

/// Unix-socket single-instance guard for Linux desktop.
///
/// The primary process binds [socketPath] and exposes [uriStream]. A secondary
/// process connects, writes one URI line (or empty), then exits.
class LinuxSingleInstance {
  LinuxSingleInstance._();

  static ServerSocket? _server;
  static StreamController<String>? _controller;
  static String? _socketPath;

  /// URIs forwarded by secondary instances (primary only).
  static Stream<String> get uriStream {
    _controller ??= StreamController<String>.broadcast();
    return _controller!.stream;
  }

  static String get socketPath {
    if (_socketPath != null) return _socketPath!;
    final runtimeDir = Platform.environment['XDG_RUNTIME_DIR'];
    if (runtimeDir != null && runtimeDir.isNotEmpty) {
      _socketPath = p.join(runtimeDir, 'sonora', 'instance.sock');
    } else {
      final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
      _socketPath = p.join(home, '.local', 'share', 'sonora', 'instance.sock');
    }
    return _socketPath!;
  }

  /// Ensures this process is the primary instance.
  ///
  /// Secondary processes send [onSecondaryUri] (may be null) and call [exit].
  /// Returns when this process should continue as primary.
  static Future<void> ensurePrimary({String? onSecondaryUri}) async {
    if (!Platform.isLinux) return;

    _controller ??= StreamController<String>.broadcast();

    final path = socketPath;
    final sockFile = File(path);
    await sockFile.parent.create(recursive: true);

    // Brief retries cover a race where the primary is still binding.
    for (var attempt = 0; attempt < 5; attempt++) {
      final forwarded = await _tryForwardToPrimary(path, onSecondaryUri);
      if (forwarded) {
        debugPrint(
          'LinuxSingleInstance: forwarded to primary, exiting '
          '(uri=${onSecondaryUri ?? "(none)"})',
        );
        exit(0);
      }
      if (attempt < 4) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    // Stale socket from a crashed primary.
    if (await sockFile.exists()) {
      try {
        await sockFile.delete();
      } catch (_) {}
    }

    try {
      final server = await ServerSocket.bind(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
      );
      _server = server;
      server.listen(
        _onConnection,
        onError: (Object e) {
          debugPrint('LinuxSingleInstance: server error: $e');
        },
      );
      debugPrint('LinuxSingleInstance: primary listening on $path');
    } catch (e) {
      // Another process won the bind race — forward and exit.
      debugPrint(
        'LinuxSingleInstance: bind failed ($e), retrying as secondary',
      );
      final forwarded = await _tryForwardToPrimary(path, onSecondaryUri);
      if (forwarded) {
        exit(0);
      }
      debugPrint(
        'LinuxSingleInstance: could not connect after bind race; continuing',
      );
    }
  }

  /// Returns `true` if the URI was sent to an existing primary.
  static Future<bool> _tryForwardToPrimary(String path, String? uri) async {
    try {
      final client = await Socket.connect(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
      );
      final payload = uri ?? '';
      client.add(utf8.encode('$payload\n'));
      await client.flush();
      await client.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  static void _onConnection(Socket client) {
    final buffer = StringBuffer();
    client.listen(
      (data) => buffer.write(utf8.decode(data)),
      onDone: () {
        final line = buffer.toString().split('\n').first.trim();
        if (line.isNotEmpty) {
          _controller?.add(line);
        } else {
          // Empty ping: still notify so the UI can show/focus the window.
          _controller?.add('');
        }
        client.destroy();
      },
      onError: (_) => client.destroy(),
      cancelOnError: true,
    );
  }

  /// Release the socket (tests / shutdown).
  static Future<void> dispose() async {
    await _server?.close();
    _server = null;
    if (_socketPath != null) {
      try {
        final f = File(_socketPath!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    await _controller?.close();
    _controller = null;
  }
}

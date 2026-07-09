import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' hide Response;
import 'package:flutter/foundation.dart';
import 'package:flutter_multicast_lock/flutter_multicast_lock.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../domain/usecases/backup/export_backup_use_case.dart';
import '../../domain/usecases/backup/merge_library_use_case.dart';

class DiscoveredSyncDevice {
  final String ip;
  final int port;
  final String name;

  DiscoveredSyncDevice({
    required this.ip,
    required this.port,
    required this.name,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredSyncDevice &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;
}

class SyncRequest {
  final String clientIp;
  final String clientName;
  final Completer<bool> completer;

  SyncRequest({
    required this.clientIp,
    required this.clientName,
    required this.completer,
  });
}

class SonoraSyncService {
  final MergeLibraryUseCase mergeLibraryUseCase;
  final ExportBackupUseCase exportBackupUseCase;
  final Dio _dio = Dio();

  HttpServer? _httpServer;
  RawDatagramSocket? _udpListenerSocket;
  final _multicastLock = FlutterMulticastLock();

  bool _isServerRunning = false;
  bool get isServerRunning => _isServerRunning;

  int? get serverPort => _httpServer?.port;

  // Stream to notify UI of incoming sync requests
  final StreamController<SyncRequest> _syncRequestsController =
      StreamController<SyncRequest>.broadcast();
  Stream<SyncRequest> get syncRequestsStream => _syncRequestsController.stream;

  // Stream to notify devices found on local network
  final StreamController<List<DiscoveredSyncDevice>> _devicesController =
      StreamController<List<DiscoveredSyncDevice>>.broadcast();
  Stream<List<DiscoveredSyncDevice>> get devicesStream =>
      _devicesController.stream;

  SonoraSyncService({
    required this.mergeLibraryUseCase,
    required this.exportBackupUseCase,
  });

  /// Starts the local HTTP server and UDP listener to be discoverable
  Future<void> startServer() async {
    if (_isServerRunning) return;

    try {
      // 1. Start local HTTP Shelf server on dynamic free port
      final app = Router();

      app.get('/api/sync/info', (Request request) {
        final info = {
          'name': _getDeviceName(),
          'platform': Platform.operatingSystem,
          'api_version': 1,
        };
        return Response.ok(
          jsonEncode(info),
          headers: {'content-type': 'application/json'},
        );
      });

      app.post('/api/sync/merge', (Request request) async {
        try {
          final payload = await request.readAsString();
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final clientName =
              data['clientName'] as String? ?? 'Dispositivo sconosciuto';
          final clientIp =
              request.context['shelf.io.connection_info']
                  as HttpConnectionInfo?;

          // Request user approval via the UI
          final completer = Completer<bool>();
          _syncRequestsController.add(
            SyncRequest(
              clientIp: clientIp?.remoteAddress.address ?? 'Sconosciuto',
              clientName: clientName,
              completer: completer,
            ),
          );

          final approved = await completer.future.timeout(
            const Duration(seconds: 30),
            onTimeout: () => false,
          );

          if (!approved) {
            return Response.forbidden(
              jsonEncode({
                'error': 'Richiesta di sincronizzazione rifiutata o scaduta.',
              }),
              headers: {'content-type': 'application/json'},
            );
          }

          // Merge remote data into server's local DB
          final libraryData = data['library'] as Map<String, dynamic>;
          await mergeLibraryUseCase.execute(libraryData);

          // Export server's merged library to send back to client
          final mergedLocalData = await exportBackupUseCase.buildBackupMap();

          return Response.ok(
            jsonEncode({'library': mergedLocalData}),
            headers: {'content-type': 'application/json'},
          );
        } catch (e) {
          debugPrint('Errore durante il merge nel server HTTP: $e');
          return Response.internalServerError(
            body: jsonEncode({'error': e.toString()}),
            headers: {'content-type': 'application/json'},
          );
        }
      });

      _httpServer = await shelf_io.serve(app.call, InternetAddress.anyIPv4, 0);
      _isServerRunning = true;
      debugPrint('Sync HTTP Server avviato sulla porta ${_httpServer!.port}');

      // 2. Start UDP Broadcast listener to respond to discovery requests
      if (Platform.isAndroid) {
        await _multicastLock.acquireMulticastLock();
      }

      _udpListenerSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        53530,
      );
      _udpListenerSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpListenerSocket!.receive();
          if (datagram != null) {
            final message = utf8.decode(datagram.data);
            if (message == 'SONORA_DISCOVERY_REQUEST') {
              final response =
                  'SONORA_DISCOVERY_RESPONSE;${_getDeviceName()};${_httpServer!.port}';
              _udpListenerSocket!.send(
                utf8.encode(response),
                datagram.address,
                datagram.port,
              );
            }
          }
        }
      });
      debugPrint('Sync UDP Listener in ascolto sulla porta 53530');
    } catch (e) {
      debugPrint('Errore nell\'avvio del server di sincronizzazione: $e');
      await stopServer();
      rethrow;
    }
  }

  /// Stops local HTTP server and UDP listener
  Future<void> stopServer() async {
    try {
      _udpListenerSocket?.close();
      _udpListenerSocket = null;

      if (Platform.isAndroid) {
        try {
          await _multicastLock.releaseMulticastLock();
        } catch (_) {}
      }

      await _httpServer?.close(force: true);
      _httpServer = null;

      _isServerRunning = false;
      debugPrint('Sync Server arrestato correttamente.');
      debugPrint('Sync Server stopped successfully.');
    } catch (e) {
      debugPrint('Error during sync server shutdown: $e');
    }
  }

  /// Scans network via UDP Broadcast to detect other Sonora devices
  Future<List<DiscoveredSyncDevice>> discoverDevices({
    Duration duration = const Duration(seconds: 4),
  }) async {
    final List<DiscoveredSyncDevice> discovered = [];
    _devicesController.add(discovered);

    RawDatagramSocket? scanSocket;
    StreamSubscription? sub;

    try {
      if (Platform.isAndroid) {
        await _multicastLock.acquireMulticastLock();
      }

      // Bind to random port to send broadcast and listen for replies
      scanSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      scanSocket.broadcastEnabled = true;

      sub = scanSocket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = scanSocket!.receive();
          if (datagram != null) {
            final message = utf8.decode(datagram.data);
            if (message.startsWith('SONORA_DISCOVERY_RESPONSE')) {
              final parts = message.split(';');
              if (parts.length >= 3) {
                final name = parts[1];
                final port = int.tryParse(parts[2]) ?? 8080;
                final ip = datagram.address.address;

                // Exclude ourselves (in case the socket receives its own broadcast response via loopback)
                if (ip != '127.0.0.1' && port != _httpServer?.port) {
                  final device = DiscoveredSyncDevice(
                    ip: ip,
                    port: port,
                    name: name,
                  );
                  if (!discovered.any(
                    (d) => d.ip == device.ip && d.port == device.port,
                  )) {
                    discovered.add(device);
                    _devicesController.add(List.unmodifiable(discovered));
                  }
                }
              }
            }
          }
        }
      });

      // Send discovery request in broadcast
      final requestBytes = utf8.encode('SONORA_DISCOVERY_REQUEST');
      scanSocket.send(requestBytes, InternetAddress('255.255.255.255'), 53530);

      // Wait specified duration to collect responses
      await Future.delayed(duration);
    } catch (e) {
      debugPrint('Error during UDP scan: $e');
    } finally {
      await sub?.cancel();
      scanSocket?.close();

      if (Platform.isAndroid && !_isServerRunning) {
        try {
          await _multicastLock.releaseMulticastLock();
        } catch (_) {}
      }
    }

    return discovered;
  }

  /// Initiates client-side synchronization: sends local data to target,
  /// awaits the response with merged data, and applies it locally.
  Future<void> performSyncWith(DiscoveredSyncDevice target) async {
    try {
      debugPrint(
        'Starting synchronization with ${target.name} (${target.ip}:${target.port})',
      );

      // 1. Build local data to send
      final localLibrary = await exportBackupUseCase.buildBackupMap();
      final requestPayload = {
        'clientName': _getDeviceName(),
        'library': localLibrary,
      };

      // 2. Perform POST request to remote server
      final response = await _dio.post(
        'http://${target.ip}:${target.port}/api/sync/merge',
        data: jsonEncode(requestPayload),
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 40),
          sendTimeout: const Duration(seconds: 40),
        ),
      );

      if (response.statusCode == 200) {
        final responseData =
            jsonDecode(response.data as String) as Map<String, dynamic>;
        final remoteMergedLibrary =
            responseData['library'] as Map<String, dynamic>;

        // 3. Apply received merged data to local DB
        await mergeLibraryUseCase.execute(remoteMergedLibrary);
        debugPrint(
          'Sincronizzazione completata con successo con ${target.name}',
        );
      } else {
        throw Exception('Server ha risposto con codice ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Errore durante l\'esecuzione della sincronizzazione: $e');
      rethrow;
    }
  }

  void dispose() {
    stopServer();
    _syncRequestsController.close();
    _devicesController.close();
  }

  String _getDeviceName() {
    if (Platform.isAndroid) {
      return 'Sonora (Android)';
    } else if (Platform.isLinux) {
      final user =
          Platform.environment['USER'] ?? Platform.environment['LOGNAME'];
      if (user != null) {
        return 'Sonora ($user - Linux)';
      }
      return 'Sonora (Linux)';
    } else {
      return 'Sonora (${Platform.operatingSystem})';
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart' hide Response;
import 'package:flutter/foundation.dart';
import 'package:flutter_multicast_lock/flutter_multicast_lock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../../domain/usecases/backup/export_backup_use_case.dart';
import '../../domain/usecases/backup/merge_library_use_case.dart';

class DiscoveredSyncDevice {
  final String ip;
  final int port;
  final String name;
  final String deviceId;

  DiscoveredSyncDevice({
    required this.ip,
    required this.port,
    required this.name,
    required this.deviceId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredSyncDevice &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port &&
          deviceId == other.deviceId;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode ^ deviceId.hashCode;
}

class PairedDeviceMetadata {
  final String deviceId;
  final String name;
  final String ip;
  final int port;

  PairedDeviceMetadata({
    required this.deviceId,
    required this.name,
    required this.ip,
    required this.port,
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'name': name,
    'ip': ip,
    'port': port,
  };

  factory PairedDeviceMetadata.fromJson(Map<String, dynamic> json) =>
      PairedDeviceMetadata(
        deviceId: json['deviceId'] as String,
        name: json['name'] as String,
        ip: json['ip'] as String,
        port: json['port'] as int,
      );
}

class PairingRequest {
  final String clientName;
  final String pin;
  final Completer<bool> completer;

  PairingRequest({
    required this.clientName,
    required this.pin,
    required this.completer,
  });
}

class SonoraSyncService {
  final MergeLibraryUseCase mergeLibraryUseCase;
  final ExportBackupUseCase exportBackupUseCase;
  final SharedPreferences _prefs;
  final Dio _dio = Dio();

  HttpServer? _httpServer;
  RawDatagramSocket? _udpListenerSocket;
  final _multicastLock = FlutterMulticastLock();

  bool _isServerRunning = false;
  bool get isServerRunning => _isServerRunning;

  int? get serverPort => _httpServer?.port;

  // Streams to notify UI of incoming pairing requests
  final StreamController<PairingRequest> _pairingRequestsController =
      StreamController<PairingRequest>.broadcast();
  Stream<PairingRequest> get pairingRequestsStream =>
      _pairingRequestsController.stream;

  // Stream to notify devices found on local network
  final StreamController<List<DiscoveredSyncDevice>> _devicesController =
      StreamController<List<DiscoveredSyncDevice>>.broadcast();
  Stream<List<DiscoveredSyncDevice>> get devicesStream =>
      _devicesController.stream;

  // Pending pairing context (Server-side)
  String? _pendingPairingClient;
  String? _pendingPairingName;
  int? _pendingPairingPort;
  String? _pendingPairingPin;
  Completer<bool>? _pendingPairingCompleter;
  Timer? _pairingTimeoutTimer;

  SonoraSyncService({
    required this.mergeLibraryUseCase,
    required this.exportBackupUseCase,
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  /// Retrieves or generates a permanent unique device identifier.
  Future<String> _getOrCreateDeviceId() async {
    String? deviceId = _prefs.getString('sync_device_id');
    if (deviceId == null) {
      final rand = Random.secure();
      final bytes = List<int>.generate(16, (i) => rand.nextInt(256));
      deviceId = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await _prefs.setString('sync_device_id', deviceId);
    }
    return deviceId;
  }

  /// Lists all paired device IDs.
  List<String> getPairedDeviceIds() {
    return getPairedDevicesMetadata().map((d) => d.deviceId).toList();
  }

  /// Lists all paired devices metadata.
  List<PairedDeviceMetadata> getPairedDevicesMetadata() {
    final list = _prefs.getStringList('paired_devices_metadata') ?? [];
    return list
        .map(
          (s) => PairedDeviceMetadata.fromJson(
            jsonDecode(s) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  /// Adds a device ID to the trusted paired list.
  Future<void> addPairedDevice(String deviceId) async {
    final list = getPairedDevicesMetadata();
    if (!list.any((item) => item.deviceId == deviceId)) {
      await savePairedDeviceMetadata(
        PairedDeviceMetadata(
          deviceId: deviceId,
          name: 'Unknown Device',
          ip: '',
          port: 8080,
        ),
      );
    }
  }

  /// Saves or updates a paired device's metadata.
  Future<void> savePairedDeviceMetadata(PairedDeviceMetadata meta) async {
    final list = getPairedDevicesMetadata();
    list.removeWhere((item) => item.deviceId == meta.deviceId);
    list.add(meta);
    final stringList = list.map((item) => jsonEncode(item.toJson())).toList();
    await _prefs.setStringList('paired_devices_metadata', stringList);
  }

  /// Removes a device ID and its metadata from the trusted paired list.
  Future<void> removePairedDevice(String deviceId) async {
    final list = getPairedDevicesMetadata();
    list.removeWhere((item) => item.deviceId == deviceId);
    final stringList = list.map((item) => jsonEncode(item.toJson())).toList();
    await _prefs.setStringList('paired_devices_metadata', stringList);
  }

  /// Clears all paired devices and metadata.
  Future<void> clearPairedDevices() async {
    await _prefs.remove('paired_devices_metadata');
  }

  /// Checks if a device ID is trusted/paired.
  bool isDevicePaired(String deviceId) {
    return getPairedDevicesMetadata().any((d) => d.deviceId == deviceId);
  }

  /// Rejects/cancels any pending pairing request.
  void cancelPendingPairing() {
    _pairingTimeoutTimer?.cancel();
    _pairingTimeoutTimer = null;
    if (_pendingPairingCompleter != null &&
        !_pendingPairingCompleter!.isCompleted) {
      _pendingPairingCompleter!.complete(false);
    }
    _pendingPairingClient = null;
    _pendingPairingName = null;
    _pendingPairingPort = null;
    _pendingPairingPin = null;
    _pendingPairingCompleter = null;
  }

  /// Starts the local HTTP server and UDP listener to be discoverable
  Future<void> startServer() async {
    if (_isServerRunning) return;

    try {
      final app = Router();

      // Retrieve device name
      app.get('/api/sync/info', (Request request) async {
        final info = {
          'name': _getDeviceName(),
          'platform': Platform.operatingSystem,
          'api_version': 1,
          'deviceId': await _getOrCreateDeviceId(),
        };
        return Response.ok(
          jsonEncode(info),
          headers: {'content-type': 'application/json'},
        );
      });

      // Endpoint to request pairing (Client -> Server)
      app.post('/api/sync/pair-request', (Request request) async {
        try {
          final payload = await request.readAsString();
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final clientId = data['clientId'] as String?;
          final clientName = data['clientName'] as String? ?? 'Unknown Device';

          if (clientId == null || clientId.isEmpty) {
            return Response.badRequest(
              body: jsonEncode({'error': 'clientId missing'}),
              headers: {'content-type': 'application/json'},
            );
          }

          // If the client requests pairing but we already have it as paired,
          // it means the client lost or reset the pairing. Remove it from our list first
          // to require a new pairing session.
          if (isDevicePaired(clientId)) {
            await removePairedDevice(clientId);
          }

          // Cancel previous pending pairing if any to close existing pairing dialog
          cancelPendingPairing();

          // Generate 4-digit pairing PIN
          final pin = (1000 + Random().nextInt(9000)).toString();

          final clientPort = data['clientPort'] as int? ?? 8080;

          _pendingPairingClient = clientId;
          _pendingPairingName = clientName;
          _pendingPairingPort = clientPort;
          _pendingPairingPin = pin;
          _pendingPairingCompleter = Completer<bool>();

          // Automatically clear pending pairing and PIN after 60 seconds
          _pairingTimeoutTimer = Timer(const Duration(seconds: 60), () {
            cancelPendingPairing();
          });

          // Notify UI on Server device
          _pairingRequestsController.add(
            PairingRequest(
              clientName: clientName,
              pin: pin,
              completer: _pendingPairingCompleter!,
            ),
          );

          return Response.ok(
            jsonEncode({'status': 'pairing_started'}),
            headers: {'content-type': 'application/json'},
          );
        } catch (e) {
          return Response.internalServerError(
            body: jsonEncode({'error': e.toString()}),
            headers: {'content-type': 'application/json'},
          );
        }
      });

      // Endpoint to verify pairing PIN (Client -> Server)
      app.post('/api/sync/pair-verify', (Request request) async {
        try {
          final payload = await request.readAsString();
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final clientId = data['clientId'] as String?;
          final pin = data['pin'] as String?;

          if (clientId == null || pin == null) {
            return Response.badRequest(
              body: jsonEncode({'error': 'clientId or pin missing'}),
              headers: {'content-type': 'application/json'},
            );
          }

          if (clientId == _pendingPairingClient && pin == _pendingPairingPin) {
            final clientIp =
                request.context['shelf.io.connection_info']
                    as HttpConnectionInfo?;
            final ipAddress = clientIp?.remoteAddress.address ?? '';
            final port = _pendingPairingPort ?? 8080;
            final name = _pendingPairingName ?? 'Unknown Device';

            await savePairedDeviceMetadata(
              PairedDeviceMetadata(
                deviceId: clientId,
                name: name,
                ip: ipAddress,
                port: port,
              ),
            );

            _pairingTimeoutTimer?.cancel();
            _pairingTimeoutTimer = null;

            if (_pendingPairingCompleter != null &&
                !_pendingPairingCompleter!.isCompleted) {
              _pendingPairingCompleter!.complete(true);
            }

            _pendingPairingClient = null;
            _pendingPairingName = null;
            _pendingPairingPort = null;
            _pendingPairingPin = null;
            _pendingPairingCompleter = null;

            final myDeviceId = await _getOrCreateDeviceId();
            return Response.ok(
              jsonEncode({
                'status': 'paired',
                'deviceId': myDeviceId,
                'deviceName': _getDeviceName(),
              }),
              headers: {'content-type': 'application/json'},
            );
          } else {
            return Response.forbidden(
              jsonEncode({'error': 'incorrect_pin'}),
              headers: {'content-type': 'application/json'},
            );
          }
        } catch (e) {
          return Response.internalServerError(
            body: jsonEncode({'error': e.toString()}),
            headers: {'content-type': 'application/json'},
          );
        }
      });

      // Endpoint to execute the actual merge (Client -> Server)
      app.post('/api/sync/merge', (Request request) async {
        try {
          final payload = await request.readAsString();
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final clientId = data['clientId'] as String?;

          if (clientId == null || !isDevicePaired(clientId)) {
            return Response.forbidden(
              jsonEncode({
                'error': 'Device not paired. Request pairing first.',
              }),
              headers: {'content-type': 'application/json'},
            );
          }

          // Merge remote library data into server's local DB automatically
          final libraryData = data['library'] as Map<String, dynamic>;
          await mergeLibraryUseCase.execute(libraryData);

          // Export server's library data to return to client
          final mergedLocalData = await exportBackupUseCase.buildBackupMap();

          return Response.ok(
            jsonEncode({'library': mergedLocalData}),
            headers: {'content-type': 'application/json'},
          );
        } catch (e) {
          debugPrint('Error during merge on HTTP server: $e');
          return Response.internalServerError(
            body: jsonEncode({'error': e.toString()}),
            headers: {'content-type': 'application/json'},
          );
        }
      });

      _httpServer = await shelf_io.serve(app.call, InternetAddress.anyIPv4, 0);
      _isServerRunning = true;
      debugPrint('Sync HTTP Server started on port ${_httpServer!.port}');

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
              unawaited(() async {
                final deviceId = await _getOrCreateDeviceId();
                final response =
                    'SONORA_DISCOVERY_RESPONSE;${_getDeviceName()};${_httpServer!.port};$deviceId';
                _udpListenerSocket!.send(
                  utf8.encode(response),
                  datagram.address,
                  datagram.port,
                );
              }());
            }
          }
        }
      });
      debugPrint('Sync UDP Listener listening on port 53530');
    } catch (e) {
      debugPrint('Error during sync server initialization: $e');
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
                final deviceId = parts.length >= 4 ? parts[3] : '';
                final ip = datagram.address.address;

                if (ip != '127.0.0.1' && port != _httpServer?.port) {
                  final device = DiscoveredSyncDevice(
                    ip: ip,
                    port: port,
                    name: name,
                    deviceId: deviceId,
                  );
                  if (!discovered.any(
                    (d) =>
                        d.ip == device.ip &&
                        d.port == device.port &&
                        d.deviceId == device.deviceId,
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

  /// Requests pairing to the target device.
  /// Returns "already_paired" or "pairing_started".
  Future<String> pairWith(DiscoveredSyncDevice target) async {
    final myDeviceId = await _getOrCreateDeviceId();
    final myDeviceName = _getDeviceName();
    final myPort = serverPort ?? 8080;

    final payload = {
      'clientId': myDeviceId,
      'clientName': myDeviceName,
      'clientPort': myPort,
    };

    final response = await _dio.post(
      'http://${target.ip}:${target.port}/api/sync/pair-request',
      data: jsonEncode(payload),
      options: Options(
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'error';
      if (status == 'already_paired') {
        await addPairedDevice(target.deviceId);
      }
      return status;
    } else {
      throw Exception('Server returned status code ${response.statusCode}');
    }
  }

  /// Verifies pairing PIN with the target device.
  Future<bool> verifyPairingPin(DiscoveredSyncDevice target, String pin) async {
    final myDeviceId = await _getOrCreateDeviceId();

    final payload = {'clientId': myDeviceId, 'pin': pin};

    final response = await _dio.post(
      'http://${target.ip}:${target.port}/api/sync/pair-verify',
      data: jsonEncode(payload),
      options: Options(
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 'paired') {
        final remoteDeviceId = data['deviceId'] as String;
        final remoteDeviceName = data['deviceName'] as String? ?? target.name;
        await savePairedDeviceMetadata(
          PairedDeviceMetadata(
            deviceId: remoteDeviceId,
            name: remoteDeviceName,
            ip: target.ip,
            port: target.port,
          ),
        );
        return true;
      }
    }
    return false;
  }

  /// Initiates client-side synchronization: sends local data to target,
  /// awaits the response with merged data, and applies it locally.
  Future<void> performSyncWith(DiscoveredSyncDevice target) async {
    try {
      debugPrint(
        'Starting synchronization with ${target.name} (${target.ip}:${target.port})',
      );

      final myDeviceId = await _getOrCreateDeviceId();
      final localLibrary = await exportBackupUseCase.buildBackupMap();
      final requestPayload = {
        'clientId': myDeviceId,
        'clientName': _getDeviceName(),
        'library': localLibrary,
      };

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

        await mergeLibraryUseCase.execute(remoteMergedLibrary);
        debugPrint(
          'Synchronization successfully completed with ${target.name}',
        );
      } else {
        throw Exception('Server responded with code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error during synchronization: $e');
      rethrow;
    }
  }

  void dispose() {
    stopServer();
    _pairingRequestsController.close();
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

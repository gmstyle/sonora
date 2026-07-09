import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/sync_service.dart';
import 'export_backup_use_case_provider.dart';
import 'merge_library_use_case_provider.dart';
import 'settings_provider.dart';

final syncServiceProvider = Provider<SonoraSyncService>((ref) {
  final service = SonoraSyncService(
    mergeLibraryUseCase: ref.watch(mergeLibraryUseCaseProvider),
    exportBackupUseCase: ref.watch(exportBackupUseCaseProvider),
  );
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

enum SyncStatus { idle, scanning, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final List<DiscoveredSyncDevice> discoveredDevices;
  final bool isServerRunning;
  final String? errorMessage;
  final String? rawErrorMessage;
  final SyncRequest? activeIncomingRequest;

  SyncState({
    this.status = SyncStatus.idle,
    this.discoveredDevices = const [],
    this.isServerRunning = false,
    this.errorMessage,
    this.rawErrorMessage,
    this.activeIncomingRequest,
  });

  SyncState copyWith({
    SyncStatus? status,
    List<DiscoveredSyncDevice>? discoveredDevices,
    bool? isServerRunning,
    String? errorMessage,
    String? rawErrorMessage,
    SyncRequest? activeIncomingRequest,
    bool clearRequest = false,
    bool clearError = false,
  }) {
    return SyncState(
      status: status ?? this.status,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      isServerRunning: isServerRunning ?? this.isServerRunning,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      rawErrorMessage:
          clearError ? null : (rawErrorMessage ?? this.rawErrorMessage),
      activeIncomingRequest:
          clearRequest
              ? null
              : (activeIncomingRequest ?? this.activeIncomingRequest),
    );
  }
}

class SyncNotifier extends Notifier<SyncState> {
  late final SonoraSyncService _service;
  StreamSubscription? _requestsSub;
  StreamSubscription? _devicesSub;

  @override
  SyncState build() {
    _service = ref.watch(syncServiceProvider);

    _requestsSub = _service.syncRequestsStream.listen((request) {
      state = state.copyWith(activeIncomingRequest: request);
    });

    _devicesSub = _service.devicesStream.listen((devices) {
      state = state.copyWith(discoveredDevices: devices);
    });

    ref.listen(settingsProvider.select((s) => s.localSyncEnabled), (
      previous,
      next,
    ) {
      if (next) {
        startServer();
      } else {
        stopServer();
      }
    }, fireImmediately: true);

    ref.onDispose(() {
      _requestsSub?.cancel();
      _devicesSub?.cancel();
    });

    return SyncState(isServerRunning: _service.isServerRunning);
  }

  Future<void> startServer() async {
    try {
      await _service.startServer();
      state = state.copyWith(isServerRunning: _service.isServerRunning);
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> stopServer() async {
    try {
      await _service.stopServer();
      state = state.copyWith(isServerRunning: _service.isServerRunning);
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> startDiscovery() async {
    state = state.copyWith(status: SyncStatus.scanning);
    try {
      await _service.discoverDevices();
      state = state.copyWith(status: SyncStatus.idle);
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> syncWith(DiscoveredSyncDevice device) async {
    state = state.copyWith(status: SyncStatus.syncing);
    try {
      await _service.performSyncWith(device);
      state = state.copyWith(status: SyncStatus.success);
    } catch (e) {
      String friendlyMessage = e.toString();
      if (e is DioException) {
        if (e.response?.statusCode == 403) {
          friendlyMessage = 'syncRejected';
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError) {
          friendlyMessage = 'connectionError';
        }
      }
      state = state.copyWith(
        status: SyncStatus.error,
        errorMessage: friendlyMessage,
        rawErrorMessage: e.toString(),
      );
    }
  }

  void respondToIncomingRequest(bool approve) {
    final req = state.activeIncomingRequest;
    if (req != null) {
      req.completer.complete(approve);
      state = state.copyWith(clearRequest: true);
    }
  }

  void resetStatus() {
    state = state.copyWith(status: SyncStatus.idle, clearError: true);
  }
}

final syncNotifierProvider = NotifierProvider<SyncNotifier, SyncState>(() {
  return SyncNotifier();
});

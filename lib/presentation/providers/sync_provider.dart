import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/utils/notification_utils.dart';
import '../../data/services/sync_service.dart';
import '../../data/services/sync_storage.dart';
import '../../domain/usecases/backup/merge_library_use_case.dart';
import 'export_backup_use_case_provider.dart';
import 'merge_library_use_case_provider.dart';
import 'settings_provider.dart';

final syncServiceProvider = Provider<SonoraSyncService>((ref) {
  final service = SonoraSyncService(
    mergeLibraryUseCase: ref.watch(mergeLibraryUseCaseProvider),
    exportBackupUseCase: ref.watch(exportBackupUseCaseProvider),
    prefs: SharedPreferencesSyncStorage(ref.watch(sharedPreferencesProvider)),
  );
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

enum SyncStatus {
  idle,
  scanning,
  syncing,
  success,
  error,
  waitingForPin,
  displayingPin,
}

class SyncState {
  final SyncStatus status;
  final List<DiscoveredSyncDevice> discoveredDevices;
  final bool isServerRunning;
  final String? errorMessage;
  final String? rawErrorMessage;
  final PairingRequest? activeIncomingRequest;
  final String? currentStage;
  final Map<String, int>? syncStats;

  SyncState({
    this.status = SyncStatus.idle,
    this.discoveredDevices = const [],
    this.isServerRunning = false,
    this.errorMessage,
    this.rawErrorMessage,
    this.activeIncomingRequest,
    this.currentStage,
    this.syncStats,
  });

  SyncState copyWith({
    SyncStatus? status,
    List<DiscoveredSyncDevice>? discoveredDevices,
    bool? isServerRunning,
    String? errorMessage,
    String? rawErrorMessage,
    PairingRequest? activeIncomingRequest,
    String? currentStage,
    Map<String, int>? syncStats,
    bool clearRequest = false,
    bool clearError = false,
    bool clearStats = false,
    bool clearStage = false,
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
      currentStage: clearStage ? null : (currentStage ?? this.currentStage),
      syncStats: clearStats ? null : (syncStats ?? this.syncStats),
    );
  }
}

class SyncNotifier extends Notifier<SyncState> {
  late final SonoraSyncService _service;
  StreamSubscription? _requestsSub;
  StreamSubscription? _devicesSub;
  StreamSubscription? _connectivitySub;
  Timer? _autoSyncTimer;
  Completer<String?>? _pinInputCompleter;
  bool _isSilentSyncing = false;

  @override
  SyncState build() {
    _service = ref.watch(syncServiceProvider);

    _requestsSub = _service.pairingRequestsStream.listen((request) {
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

    // Setup background auto sync
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      dynamic r = results;
      bool hasWifi = false;
      if (r is Iterable) {
        hasWifi = r.contains(ConnectivityResult.wifi);
      } else if (r == ConnectivityResult.wifi) {
        hasWifi = true;
      }
      if (hasWifi) {
        triggerSilentSync();
      }
    });

    _autoSyncTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      triggerSilentSync();
    });

    // Run a silent sync at startup
    Future.microtask(() => triggerSilentSync());

    ref.onDispose(() {
      _requestsSub?.cancel();
      _devicesSub?.cancel();
      _connectivitySub?.cancel();
      _autoSyncTimer?.cancel();
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
    bool isPairingPhase = false;
    try {
      // Check if already paired
      final isAlreadyPaired = _service.isDevicePaired(device.deviceId);
      if (!isAlreadyPaired) {
        isPairingPhase = true;
        // Request pairing
        final status = await _service.pairWith(device);
        if (status == 'pairing_started') {
          // Transition to waitingForPin
          state = state.copyWith(status: SyncStatus.waitingForPin);

          // Await user PIN input from the UI
          _pinInputCompleter = Completer<String?>();
          final pin = await _pinInputCompleter!.future;
          _pinInputCompleter = null;

          if (pin == null || pin.isEmpty) {
            // Pairing cancelled
            state = state.copyWith(status: SyncStatus.idle);
            return;
          }

          state = state.copyWith(status: SyncStatus.syncing);
          final success = await _service.verifyPairingPin(device, pin);
          if (!success) {
            throw Exception('incorrect_pin');
          }
        }
      }

      isPairingPhase = false;
      final settings = ref.read(settingsProvider);
      final strategyStr = settings.playlistConflictStrategy;
      final conflictStrategy = PlaylistConflictStrategy.values.firstWhere(
        (e) => e.name == strategyStr,
        orElse: () => PlaylistConflictStrategy.merge,
      );

      // Proceed with the merge sync
      final stats = await _service.performSyncWith(
        device,
        onStageChanged: (stage) {
          state = state.copyWith(currentStage: stage);
        },
        conflictStrategy: conflictStrategy,
      );

      // Save/update paired device metadata with latest IP/port
      await _service.savePairedDeviceMetadata(
        PairedDeviceMetadata(
          deviceId: device.deviceId,
          name: device.name,
          ip: device.ip,
          port: device.port,
        ),
      );

      state = state.copyWith(
        status: SyncStatus.success,
        syncStats: stats,
        clearStage: true,
      );
    } catch (e) {
      String friendlyMessage = e.toString();
      if (friendlyMessage.contains('incorrect_pin')) {
        friendlyMessage = 'incorrectPin';
      } else if (e is DioException) {
        final dynamic responseData = e.response?.data;
        final responseString =
            responseData is Map
                ? (responseData['error'] ?? '').toString()
                : responseData.toString();
        if (responseString.contains('incorrect_pin')) {
          friendlyMessage = 'incorrectPin';
        } else if (e.response?.statusCode == 403) {
          friendlyMessage = isPairingPhase ? 'syncRejected' : 'pairingRemoved';
          await _service.removePairedDevice(device.deviceId);
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
        clearStage: true,
      );
    }
  }

  void resetSuccessState() {
    state = state.copyWith(
      status: SyncStatus.idle,
      clearStats: true,
      clearStage: true,
    );
  }

  void submitPin(String pin) {
    if (_pinInputCompleter != null && !_pinInputCompleter!.isCompleted) {
      _pinInputCompleter!.complete(pin);
    }
  }

  void cancelPinInput() {
    if (_pinInputCompleter != null && !_pinInputCompleter!.isCompleted) {
      _pinInputCompleter!.complete(null);
    }
  }

  void respondToIncomingRequest(bool approve) {
    final req = state.activeIncomingRequest;
    if (req != null) {
      if (!approve) {
        _service.cancelPendingPairing();
      }
      state = state.copyWith(clearRequest: true);
    }
  }

  Future<void> clearPairedDevices() async {
    await _service.clearPairedDevices();
  }

  void resetStatus() {
    state = state.copyWith(status: SyncStatus.idle, clearError: true);
  }

  Future<void> triggerSilentSync() async {
    if (_isSilentSyncing) return;
    final settings = ref.read(settingsProvider);
    if (!settings.localSyncEnabled || !settings.localSyncAutoEnabled) return;

    _isSilentSyncing = true;
    try {
      debugPrint('[Auto Sync] Starting discovery...');
      final discovered = await _service.discoverDevices(
        duration: const Duration(seconds: 2),
      );
      final paired = _service.getPairedDevicesMetadata();

      for (final device in discovered) {
        if (paired.any((p) => p.deviceId == device.deviceId)) {
          debugPrint(
            '[Auto Sync] Found paired device online: ${device.name}. Syncing...',
          );

          final strategyStr = settings.playlistConflictStrategy;
          final conflictStrategy = PlaylistConflictStrategy.values.firstWhere(
            (e) => e.name == strategyStr,
            orElse: () => PlaylistConflictStrategy.merge,
          );

          final stats = await _service.performSyncWith(
            device,
            conflictStrategy: conflictStrategy,
          );

          // Save latest IP/port
          await _service.savePairedDeviceMetadata(
            PairedDeviceMetadata(
              deviceId: device.deviceId,
              name: device.name,
              ip: device.ip,
              port: device.port,
            ),
          );

          final totalChanges =
              (stats['likedSongs'] ?? 0) +
              (stats['playlists'] ?? 0) +
              (stats['followedArtists'] ?? 0) +
              (stats['likedAlbums'] ?? 0) +
              (stats['history'] ?? 0);

          if (totalChanges > 0) {
            debugPrint('[Auto Sync] Sync complete, $totalChanges items added.');
            final locale = Locale(settings.hl);
            final l10n = await AppLocalizations.delegate.load(locale);

            try {
              await flutterLocalNotificationsPlugin.show(
                id: 9999,
                title: l10n.notificationSyncTitle,
                body: l10n.notificationSyncBody(totalChanges),
                notificationDetails: NotificationDetails(
                  android: const AndroidNotificationDetails(
                    'sonora_sync',
                    'Sonora Synchronization',
                    importance: Importance.defaultImportance,
                  ),
                  linux: LinuxNotificationDetails(
                    defaultActionName: l10n.accept,
                  ),
                ),
              );
            } catch (e) {
              debugPrint('[Auto Sync] Failed to show local notification: $e');
            }
          } else {
            debugPrint('[Auto Sync] Sync complete, no changes.');
          }
        }
      }
    } catch (e) {
      debugPrint('[Auto Sync] Error during auto sync: $e');
    } finally {
      _isSilentSyncing = false;
    }
  }
}

final syncNotifierProvider = NotifierProvider<SyncNotifier, SyncState>(() {
  return SyncNotifier();
});

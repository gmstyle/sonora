import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';

enum ConnectivityStatus { isConnected, isDisconnected }

class ConnectivityNotifier extends Notifier<ConnectivityStatus> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  ConnectivityStatus build() {
    final connectivity = Connectivity();

    _subscription = connectivity.onConnectivityChanged.listen((results) {
      state = _mapResultsToStatus(results);
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    // Fetch initial status asynchronously to update state as soon as possible.
    connectivity.checkConnectivity().then((results) {
      state = _mapResultsToStatus(results);
    });

    return ConnectivityStatus
        .isConnected; // Default to connected until first check
  }

  ConnectivityStatus _mapResultsToStatus(List<ConnectivityResult> results) {
    if (results.isEmpty ||
        (results.length == 1 && results.contains(ConnectivityResult.none))) {
      return ConnectivityStatus.isDisconnected;
    }
    return ConnectivityStatus.isConnected;
  }
}

final connectivityStatusProvider =
    NotifierProvider<ConnectivityNotifier, ConnectivityStatus>(
      ConnectivityNotifier.new,
    );

final isOfflineProvider = Provider<bool>((ref) {
  final manualOffline = ref.watch(settingsProvider).offlineMode;
  if (manualOffline) return true;
  final status = ref.watch(connectivityStatusProvider);
  return status == ConnectivityStatus.isDisconnected;
});

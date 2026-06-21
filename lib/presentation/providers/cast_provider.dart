import 'dart:async';
import 'dart:io';
import 'package:dart_cast/dart_cast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_settings_plus/open_settings_plus.dart';
import '../../data/services/cast_service.dart';

enum CastConnectionState { disconnected, connecting, connected, error }

class CastState {
  final bool isDiscovering;
  final List<CastDevice> discoveredDevices;
  final CastDevice? activeDevice;
  final CastConnectionState connectionState;

  CastState({
    this.isDiscovering = false,
    this.discoveredDevices = const [],
    this.activeDevice,
    this.connectionState = CastConnectionState.disconnected,
  });

  CastState copyWith({
    bool? isDiscovering,
    List<CastDevice>? discoveredDevices,
    CastDevice? activeDevice,
    CastConnectionState? connectionState,
  }) {
    return CastState(
      isDiscovering: isDiscovering ?? this.isDiscovering,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      activeDevice: activeDevice ?? this.activeDevice,
      connectionState: connectionState ?? this.connectionState,
    );
  }
}

final castServiceProvider = Provider((ref) {
  final service = SonoraCastService();
  ref.onDispose(() => service.dispose());
  return service;
});

class CastNotifier extends AsyncNotifier<CastState> {
  late final SonoraCastService _service;
  StreamSubscription? _devicesSubscription;

  @override
  FutureOr<CastState> build() {
    _service = ref.watch(castServiceProvider);
    return CastState();
  }

  void startDiscovery() {
    state = AsyncData(state.value!.copyWith(isDiscovering: true));
    _service.startDiscovery();
    _devicesSubscription?.cancel();
    _devicesSubscription = _service.devicesStream.listen((devices) {
      state = AsyncData(state.value!.copyWith(discoveredDevices: devices));
    });
  }

  void stopDiscovery() {
    _service.stopDiscovery();
    _devicesSubscription?.cancel();
    state = AsyncData(state.value!.copyWith(isDiscovering: false));
  }

  Future<void> connect(CastDevice device) async {
    state = AsyncData(
      state.value!.copyWith(
        connectionState: CastConnectionState.connecting,
        activeDevice: device,
      ),
    );

    final session = await _service.connect(device);
    if (session != null) {
      state = AsyncData(
        state.value!.copyWith(connectionState: CastConnectionState.connected),
      );
    } else {
      state = AsyncData(
        state.value!.copyWith(
          connectionState: CastConnectionState.error,
          activeDevice: null,
        ),
      );
    }
  }

  Future<void> disconnect() async {
    await _service.disconnect();
    state = AsyncData(
      state.value!.copyWith(
        connectionState: CastConnectionState.disconnected,
        activeDevice: null,
      ),
    );
  }

  void openBluetoothSettings() {
    if (Platform.isAndroid) {
      const OpenSettingsPlusAndroid().bluetooth();
    } else if (Platform.isLinux) {
      Process.run('gnome-control-center', ['bluetooth']);
      // Add more for other DEs if needed, or use a more generic way
    }
  }
}

final castStateProvider =
    AsyncNotifierProvider.autoDispose<CastNotifier, CastState>(() {
      return CastNotifier();
    });

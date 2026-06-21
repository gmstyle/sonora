import 'dart:async';
import 'package:dart_cast/dart_cast.dart';
import 'package:flutter/foundation.dart';

class SonoraCastService {
  final CastService _castService = CastService(
    discoveryProviders: [
      ChromecastDiscoveryProvider(),
      DlnaDiscoveryProvider(),
    ],
  );

  final StreamController<List<CastDevice>> _devicesController =
      StreamController<List<CastDevice>>.broadcast();
  final List<CastDevice> _devices = [];

  CastSession? _activeSession;
  StreamSubscription? _discoverySubscription;

  final StreamController<SessionState> _stateController =
      StreamController<SessionState>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  StreamSubscription? _stateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  Stream<List<CastDevice>> get devicesStream => _devicesController.stream;
  CastSession? get activeSession => _activeSession;

  Stream<SessionState> get stateStream => _stateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;

  void startDiscovery() {
    _devices.clear();
    _devicesController.add(_devices);
    _discoverySubscription?.cancel();
    _discoverySubscription = _castService.startDiscovery().listen((
      List<CastDevice> discoveredList,
    ) {
      for (final device in discoveredList) {
        if (!_devices.any((d) => d.id == device.id)) {
          _devices.add(device);
        }
      }
      // Rimuovi dispositivi non più presenti nella lista scoperta
      _devices.removeWhere(
        (d) => !discoveredList.any((device) => device.id == d.id),
      );
      _devicesController.add(List.unmodifiable(_devices));
    });
  }

  void stopDiscovery() {
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    _castService.stopDiscovery();
  }

  Future<CastSession?> connect(CastDevice device) async {
    await disconnect();

    try {
      if (device.protocol == CastProtocol.chromecast) {
        _activeSession = ChromecastSession(device: device);
      } else if (device.protocol == CastProtocol.dlna) {
        _activeSession = DlnaSession.fromDevice(device);
      }

      if (_activeSession != null) {
        await _activeSession!.connect();
        _listenToSession(_activeSession!);
        return _activeSession;
      }
    } catch (e) {
      debugPrint('Error connecting to cast device: $e');
      _activeSession = null;
    }
    return null;
  }

  Future<void> disconnect() async {
    _stopListeningToSession();
    if (_activeSession != null) {
      try {
        await _activeSession!.disconnect();
      } catch (e) {
        debugPrint('Error disconnecting from cast device: $e');
      }
      _activeSession = null;
    }
  }

  Future<void> castMedia({
    required String url,
    required String title,
    String? artist,
    String? album,
    String? artworkUrl,
    String? contentType,
    Duration? startPosition,
  }) async {
    if (_activeSession == null) return;

    final mediaTitle = artist != null ? '$artist - $title' : title;

    await _activeSession!.loadMedia(
      CastMedia(
        url: url,
        type:
            CastMediaType.mp4, // YouTube audio streams are progressive MP4/AAC
        title: mediaTitle,
        imageUrl: artworkUrl,
        startPosition: startPosition,
      ),
    );
  }

  Future<void> play() async => await _activeSession?.play();
  Future<void> pause() async => await _activeSession?.pause();
  Future<void> seek(Duration position) async =>
      await _activeSession?.seek(position);
  Future<void> setVolume(double volume) async =>
      await _activeSession?.setVolume(volume);

  void _listenToSession(CastSession session) {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();

    _stateController.add(session.state);
    _positionController.add(session.position);
    _durationController.add(session.duration);

    _stateSub = session.stateStream.listen((state) {
      _stateController.add(state);
    });
    _positionSub = session.positionStream.listen((pos) {
      _positionController.add(pos);
    });
    _durationSub = session.durationStream.listen((dur) {
      _durationController.add(dur);
    });
  }

  void _stopListeningToSession() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateController.add(SessionState.disconnected);
  }

  void dispose() {
    stopDiscovery();
    _devicesController.close();
    _stateController.close();
    _positionController.close();
    _durationController.close();
    disconnect();
  }
}

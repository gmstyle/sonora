import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../../presentation/features/player/audio_handler.dart';

class LinuxTrayService {
  static LinuxTrayService? _instance;
  static SonoraAudioHandler? _audioHandler;

  static void setInstance(LinuxTrayService service) {
    _instance = service;
  }

  static void setAudioHandler(SonoraAudioHandler handler) {
    _audioHandler = handler;
  }

  static LinuxTrayService? get instance => _instance;

  bool _isPlaying = false;

  Future<void> init() async {
    _instance = this;
    await trayManager.setIcon(_getTrayIcon());
    // setToolTip is not implemented on Linux; ignore the error
    try {
      await trayManager.setToolTip('Sonora');
    } catch (_) {}
    await _updateMenu();
    trayManager.addListener(_TrayListener(this));
  }

  String _getTrayIcon() {
    // tray_manager on Linux needs an absolute filesystem path.
    // In a Flutter linux bundle the structure is:
    //   bundle/sonora  (executable)
    //   bundle/data/flutter_assets/assets/icons/tray/tray_icon.png
    final execDir = p.dirname(Platform.resolvedExecutable);
    final bundlePath = p.join(
      execDir,
      'data',
      'flutter_assets',
      'assets',
      'icons',
      'tray',
      'tray_icon.png',
    );
    // During `flutter run` (debug/profile) the asset is in the project dir
    final devPath = p.join(
      Directory.current.path,
      'assets',
      'icons',
      'tray',
      'tray_icon.png',
    );
    return File(bundlePath).existsSync() ? bundlePath : devPath;
  }

  Future<void> updatePlaybackState(
    bool isPlaying, {
    String? title,
    String? artist,
  }) async {
    _isPlaying = isPlaying;

    await _updateMenu();

    // setToolTip is not implemented on Linux; skip silently
    try {
      final tooltip =
          (title != null && artist != null) ? '$artist - $title' : 'Sonora';
      await trayManager.setToolTip(tooltip);
    } catch (_) {}
  }

  Future<void> _updateMenu() async {
    final menu = Menu(
      items: [
        MenuItem(key: 'play_pause', label: _isPlaying ? '⏸ Pause' : '▶ Play'),
        MenuItem(key: 'prev', label: '⏮ Previous'),
        MenuItem(key: 'next', label: '⏭ Next'),
        MenuItem.separator(),
        MenuItem(key: 'show', label: '📥 Show Sonora'),
        MenuItem(key: 'quit', label: '🚪 Quit'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  Future<void> handleMenuItemClick(String key) async {
    switch (key) {
      case 'play_pause':
        await _sendPlayPauseAction();
        break;
      case 'prev':
        await _sendPreviousAction();
        break;
      case 'next':
        await _sendNextAction();
        break;
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'quit':
        await windowManager.setPreventClose(false);
        await windowManager.close();
        break;
    }
  }

  Future<void> _sendPlayPauseAction() async {
    if (_audioHandler != null) {
      if (_isPlaying) {
        await _audioHandler!.pause();
      } else {
        await _audioHandler!.play();
      }
    }
  }

  Future<void> _sendPreviousAction() async {
    await _audioHandler?.skipToPrevious();
  }

  Future<void> _sendNextAction() async {
    await _audioHandler?.skipToNext();
  }

  void dispose() {
    trayManager.removeListener(_TrayListener(this));
  }
}

class _TrayListener extends TrayListener {
  final LinuxTrayService _service;

  _TrayListener(this._service);

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem item) {
    if (item.key != null) {
      _service.handleMenuItemClick(item.key!);
    }
  }
}

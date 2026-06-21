import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
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
  String? _currentTitle;
  String? _currentArtist;
  AudioServiceShuffleMode _shuffleMode = AudioServiceShuffleMode.none;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

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
    // In the installed bundle, tray_icon.png sits alongside the executable.
    final execDir = p.dirname(Platform.resolvedExecutable);
    final bundlePath = p.join(execDir, 'tray_icon.png');

    // During `flutter run` (debug/profile) the asset is in the project dir.
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
    AudioServiceShuffleMode? shuffleMode,
    AudioServiceRepeatMode? repeatMode,
  }) async {
    _isPlaying = isPlaying;
    _currentTitle = title;
    _currentArtist = artist;
    if (shuffleMode != null) _shuffleMode = shuffleMode;
    if (repeatMode != null) _repeatMode = repeatMode;

    await _updateMenu();

    // setToolTip is not implemented on Linux; skip silently
    try {
      final tooltip =
          (title != null && artist != null) ? '$artist - $title' : 'Sonora';
      await trayManager.setToolTip(tooltip);
    } catch (_) {}
  }

  Future<void> _updateMenu() async {
    final List<MenuItem> items = [];

    if (_currentTitle != null) {
      items.add(
        MenuItem(
          key: 'now_playing_header',
          label: 'Now Playing:',
          disabled: true,
        ),
      );
      items.add(
        MenuItem(
          key: 'current_track',
          label: '  $_currentTitle',
          disabled: true,
        ),
      );
      if (_currentArtist != null) {
        items.add(
          MenuItem(
            key: 'current_artist',
            label: '  by $_currentArtist',
            disabled: true,
          ),
        );
      }
      items.add(MenuItem.separator());
    }

    items.addAll([
      MenuItem(key: 'play_pause', label: _isPlaying ? '⏸  Pause' : '▶  Play'),
      MenuItem(key: 'prev', label: '⏮  Previous'),
      MenuItem(key: 'next', label: '⏭  Next'),
    ]);

    items.add(MenuItem.separator());

    final isShuffle = _shuffleMode == AudioServiceShuffleMode.all;
    items.add(
      MenuItem(
        key: 'shuffle',
        label: isShuffle ? '🔀  Shuffle: On' : '🔀  Shuffle: Off',
      ),
    );

    final repeatLabel = switch (_repeatMode) {
      AudioServiceRepeatMode.one => '🔂  Repeat: One',
      AudioServiceRepeatMode.all => '🔁  Repeat: All',
      _ => '🔁  Repeat: Off',
    };
    items.add(MenuItem(key: 'repeat', label: repeatLabel));

    items.add(MenuItem.separator());

    items.addAll([
      MenuItem(key: 'show', label: 'Restore Sonora'),
      MenuItem(key: 'quit', label: 'Quit'),
    ]);

    final menu = Menu(items: items);
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
      case 'shuffle':
        await _toggleShuffle();
        break;
      case 'repeat':
        await _cycleRepeatMode();
        break;
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'quit':
        if (_audioHandler != null) {
          await _audioHandler!.stop();
        }
        await windowManager.setPreventClose(false);
        await windowManager.close();
        break;
    }
  }

  Future<void> _toggleShuffle() async {
    final newMode =
        _shuffleMode == AudioServiceShuffleMode.none
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none;
    await _audioHandler?.setShuffleMode(newMode);
  }

  Future<void> _cycleRepeatMode() async {
    const modes = [
      AudioServiceRepeatMode.none,
      AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.one,
    ];
    final idx = modes.indexOf(_repeatMode);
    final next = modes[(idx + 1) % modes.length];
    await _audioHandler?.setRepeatMode(next);
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

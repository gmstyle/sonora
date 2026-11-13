import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../presentation/features/player/audio_handler.dart';

class LinuxTrayService {
  static LinuxTrayService? _instance;
  static SonoraAudioHandler? _audioHandler;
  static bool _isQuitRequested = false;

  static bool get isQuitRequested => _isQuitRequested;

  static void closeWindowForQuit() {
    _isQuitRequested = true;
    WindowManager.instance.getCurrent()?.close();
  }

  /// Shows the window and paints into the Wayland surface GTK creates on map.
  ///
  /// [Window.hide] destroys that surface. The frame scheduled during [Window.show]
  /// can still target the old one, and a transparent view then stays blank.
  /// A size pulse after the tray menu closes runs [Window.setSize] once the new
  /// surface exists, which is what makes the embedder present again.
  static void presentWindow() {
    final window = WindowManager.instance.getCurrent();
    if (window == null) return;
    window.show();
    window.focus();
    if (window.isMaximized) {
      Timer(const Duration(milliseconds: 50), () {
        SchedulerBinding.instance.scheduleForcedFrame();
      });
      return;
    }
    final size = window.size.toSize();
    Timer(const Duration(milliseconds: 50), () {
      window.setSize(ui.Size(size.width + 1, size.height).toNative(), false);
      Timer(const Duration(milliseconds: 50), () {
        window.setSize(size.toNative(), false);
        SchedulerBinding.instance.scheduleForcedFrame();
      });
    });
  }

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

  TrayIcon? _icon;
  Menu? _menu;

  Future<void> init() async {
    _instance = this;
    final icon = TrayIcon.createWithIdentifier('sonora');
    if (icon == null) {
      debugPrint('Linux tray: TrayIcon.create failed');
      return;
    }
    _icon = icon;

    final image = Image.fromFile(_trayIconPath());
    if (image == null) {
      debugPrint('Linux tray: icon file missing at ${_trayIconPath()}');
    } else {
      icon.icon = image;
      // Alpha is the glyph. The panel foreground tints it, like the other
      // status icons.
      icon.isIconTemplate = true;
    }
    icon.setTooltip('Sonora');
    // Linux panels draw the exported menu themselves and do not deliver
    // TrayIconClickedEvent. clicked still publishes that menu.
    icon.setContextMenuTrigger(ContextMenuTrigger.clicked);
    icon.addListener((event) {
      if (event is TrayIconClickedEvent) _showWindow();
    });
    _updateMenu();
    icon.setVisible(true);
  }

  String _trayIconPath() {
    // `flutter run` from the repo. An installed bundle has the copy beside the executable.
    final devPath = p.join(
      Directory.current.path,
      'assets',
      'icons',
      'tray',
      'tray_symbolic.png',
    );
    if (File(devPath).existsSync()) return devPath;

    return p.join(p.dirname(Platform.resolvedExecutable), 'tray_icon.png');
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

    _updateMenu();

    final tooltip = (title != null && artist != null)
        ? '$artist - $title'
        : 'Sonora';
    _icon?.setTooltip(tooltip);
  }

  void _updateMenu() {
    final icon = _icon;
    if (icon == null) return;

    final menu = Menu.create();
    if (menu == null) {
      debugPrint('Linux tray: Menu.create failed');
      return;
    }

    if (_currentTitle != null) {
      _addItem(menu, 'Now Playing:', enabled: false);
      _addItem(menu, '  $_currentTitle', enabled: false);
      if (_currentArtist != null) {
        _addItem(menu, '  by $_currentArtist', enabled: false);
      }
      menu.addSeparator();
    }

    _addItem(
      menu,
      _isPlaying ? '⏸  Pause' : '▶  Play',
      onClick: _sendPlayPauseAction,
    );
    _addItem(menu, '⏮  Previous', onClick: _sendPreviousAction);
    _addItem(menu, '⏭  Next', onClick: _sendNextAction);

    menu.addSeparator();

    final isShuffle = _shuffleMode == AudioServiceShuffleMode.all;
    _addItem(
      menu,
      isShuffle ? '🔀  Shuffle: On' : '🔀  Shuffle: Off',
      onClick: _toggleShuffle,
    );

    final repeatLabel = switch (_repeatMode) {
      AudioServiceRepeatMode.one => '🔂  Repeat: One',
      AudioServiceRepeatMode.all => '🔁  Repeat: All',
      _ => '🔁  Repeat: Off',
    };
    _addItem(menu, repeatLabel, onClick: _cycleRepeatMode);

    menu.addSeparator();

    _addItem(menu, 'Restore Sonora', onClick: () async => _showWindow());
    _addItem(menu, 'Quit', onClick: _quit);

    icon.setContextMenu(menu);
    final previous = _menu;
    _menu = menu;
    previous?.dispose();
  }

  void _addItem(
    Menu menu,
    String label, {
    bool enabled = true,
    Future<void> Function()? onClick,
  }) {
    final item = MenuItem.createWithLabelAndType(label, MenuItemType.normal);
    if (item == null) return;
    item.isEnabled = enabled;
    if (enabled && onClick != null) {
      item.addListener((event) {
        if (event is MenuItemClickedEvent) unawaited(onClick());
      });
    }
    menu.addItem(item);
  }

  void _showWindow() {
    LinuxTrayService.presentWindow();
  }

  Future<void> _quit() async {
    if (_audioHandler != null) {
      await _audioHandler!.stop();
    }
    closeWindowForQuit();
  }

  Future<void> _toggleShuffle() async {
    final newMode = _shuffleMode == AudioServiceShuffleMode.none
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
    _menu?.dispose();
    _menu = null;
    _icon?.dispose();
    _icon = null;
  }
}

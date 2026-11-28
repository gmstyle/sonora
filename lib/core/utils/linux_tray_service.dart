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
import 'linux_single_instance.dart';
import 'linux_tray_models.dart';

/// Callbacks wired by the mounted Flutter tree to handle tray menu actions.
class LinuxTrayCallbacks {
  final Future<void> Function()? onOpenNowPlaying;
  final Future<void> Function()? onPlayPause;
  final Future<void> Function()? onPrevious;
  final Future<void> Function()? onNext;
  final Future<void> Function()? onToggleLike;
  final Future<void> Function()? onToggleShuffle;
  final Future<void> Function(AudioServiceRepeatMode mode)? onSetRepeatMode;
  final Future<void> Function(int index)? onSkipToQueueIndex;
  final void Function(int? minutes)? onSetSleepMinutes;
  final void Function()? onSetSleepEndOfTrack;
  final void Function()? onToggleMute;
  final void Function(int percent)? onSetVolumePercent;
  final Future<void> Function()? onToggleOffline;
  final Future<void> Function(String route)? onNavigate;
  final Future<void> Function()? onResumeLast;
  final Future<void> Function()? onShuffleLiked;

  const LinuxTrayCallbacks({
    this.onOpenNowPlaying,
    this.onPlayPause,
    this.onPrevious,
    this.onNext,
    this.onToggleLike,
    this.onToggleShuffle,
    this.onSetRepeatMode,
    this.onSkipToQueueIndex,
    this.onSetSleepMinutes,
    this.onSetSleepEndOfTrack,
    this.onToggleMute,
    this.onSetVolumePercent,
    this.onToggleOffline,
    this.onNavigate,
    this.onResumeLast,
    this.onShuffleLiked,
  });
}

class LinuxTrayService {
  static LinuxTrayService? _instance;
  static SonoraAudioHandler? _audioHandler;
  static Future<void> Function()? _onQuit;
  static bool _isQuitRequested = false;

  static void setOnQuit(Future<void> Function()? callback) {
    _onQuit = callback;
  }

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
    _instance?.setWindowVisible(true);
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

  /// Hides the window to the Linux tray and updates the tray menu toggle.
  static void hideWindow() {
    final window = WindowManager.instance.getCurrent();
    if (window == null) return;
    window.hide();
    _instance?.setWindowVisible(false);
  }

  static void setInstance(LinuxTrayService service) {
    _instance = service;
  }

  static void setAudioHandler(SonoraAudioHandler handler) {
    _audioHandler = handler;
  }

  static LinuxTrayService? get instance => _instance;

  LinuxTraySnapshot _snapshot = const LinuxTraySnapshot();
  LinuxTrayLabels _labels = LinuxTrayLabels.fallbackEn;
  LinuxTrayCallbacks _callbacks = const LinuxTrayCallbacks();

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
    _rebuildMenu();
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

  /// Binds UI-layer callbacks (PlayerNotifier, SettingsNotifier, GoRouter, etc.).
  void setCallbacks(LinuxTrayCallbacks callbacks) {
    _callbacks = callbacks;
  }

  /// Updates the tray menu and tooltip if [snapshot] or [labels] changed.
  void updateSnapshot(LinuxTraySnapshot snapshot, LinuxTrayLabels labels) {
    if (snapshot == _snapshot && labels == _labels) return;
    _snapshot = snapshot;
    _labels = labels;
    _rebuildMenu();
    _icon?.setTooltip(buildLinuxTrayTooltip(_snapshot, _labels));
  }

  /// Updates whether the main window is currently visible.
  void setWindowVisible(bool visible) {
    if (_snapshot.isWindowVisible == visible) return;
    _snapshot = _snapshot.copyWith(isWindowVisible: visible);
    _rebuildMenu();
  }

  /// Legacy convenience update for callers that only track basic playback state.
  Future<void> updatePlaybackState(
    bool isPlaying, {
    String? title,
    String? artist,
    AudioServiceShuffleMode? shuffleMode,
    AudioServiceRepeatMode? repeatMode,
  }) async {
    final next = _snapshot.copyWith(
      isPlaying: isPlaying,
      title: title,
      artist: artist,
      clearTrack: title == null,
      shuffleMode: shuffleMode,
      repeatMode: repeatMode,
      hasQueue: title != null || _snapshot.hasQueue,
    );
    updateSnapshot(next, _labels);
  }

  void _rebuildMenu() {
    final icon = _icon;
    if (icon == null) return;

    final menu = Menu.create();
    if (menu == null) {
      debugPrint('Linux tray: Menu.create failed');
      return;
    }

    final spec = buildLinuxTrayMenuSpec(_snapshot, _labels);
    _populateMenu(menu, spec);

    icon.setContextMenu(menu);
    final previous = _menu;
    _menu = menu;
    previous?.dispose();
  }

  void _populateMenu(Menu menu, List<LinuxTrayMenuEntry> entries) {
    for (final entry in entries) {
      switch (entry.kind) {
        case LinuxTrayMenuItemKind.separator:
          menu.addSeparator();
        case LinuxTrayMenuItemKind.normal:
          final item = MenuItem.createWithLabelAndType(
            entry.label,
            MenuItemType.normal,
          );
          if (item == null) continue;
          item.isEnabled = entry.enabled;
          if (entry.enabled && entry.action != null) {
            final action = entry.action!;
            item.addListener((event) {
              if (event is MenuItemClickedEvent) {
                unawaited(_dispatchAction(action));
              }
            });
          }
          menu.addItem(item);
        case LinuxTrayMenuItemKind.checkbox:
          final item = MenuItem.createWithLabelAndType(
            entry.label,
            MenuItemType.checkbox,
          );
          if (item == null) continue;
          item.isEnabled = entry.enabled;
          item.state = entry.checked
              ? MenuItemState.checked
              : MenuItemState.unchecked;
          if (entry.enabled && entry.action != null) {
            final action = entry.action!;
            item.addListener((event) {
              if (event is MenuItemClickedEvent) {
                unawaited(_dispatchAction(action));
              }
            });
          }
          menu.addItem(item);
        case LinuxTrayMenuItemKind.radio:
          final item = MenuItem.createWithLabelAndType(
            entry.label,
            MenuItemType.radio,
          );
          if (item == null) continue;
          item.isEnabled = entry.enabled;
          if (entry.radioGroup != null) {
            item.radioGroup = entry.radioGroup!;
          }
          item.state = entry.checked
              ? MenuItemState.checked
              : MenuItemState.unchecked;
          if (entry.enabled && entry.action != null) {
            final action = entry.action!;
            item.addListener((event) {
              if (event is MenuItemClickedEvent) {
                unawaited(_dispatchAction(action));
              }
            });
          }
          menu.addItem(item);
        case LinuxTrayMenuItemKind.submenu:
          final submenu = Menu.create();
          final item = MenuItem.createWithLabelAndType(
            entry.label,
            MenuItemType.submenu,
          );
          if (submenu == null || item == null) continue;
          item.isEnabled = entry.enabled;
          if (entry.children.isNotEmpty) {
            _populateMenu(submenu, entry.children);
            item.submenu = submenu;
          }
          menu.addItem(item);
      }
    }
  }

  Future<void> _dispatchAction(LinuxTrayAction action) async {
    switch (action) {
      case OpenNowPlayingTrayAction():
        if (_callbacks.onOpenNowPlaying != null) {
          await _callbacks.onOpenNowPlaying!();
        } else {
          _showWindow();
        }
      case PlayPauseTrayAction():
        if (_callbacks.onPlayPause != null) {
          await _callbacks.onPlayPause!();
        } else {
          await _sendPlayPauseAction();
        }
      case PreviousTrayAction():
        if (_callbacks.onPrevious != null) {
          await _callbacks.onPrevious!();
        } else {
          await _audioHandler?.skipToPrevious();
        }
      case NextTrayAction():
        if (_callbacks.onNext != null) {
          await _callbacks.onNext!();
        } else {
          await _audioHandler?.skipToNext();
        }
      case ToggleLikeTrayAction():
        if (_callbacks.onToggleLike != null) {
          await _callbacks.onToggleLike!();
        } else {
          await _audioHandler?.toggleCurrentLike();
        }
      case ToggleShuffleTrayAction():
        if (_callbacks.onToggleShuffle != null) {
          await _callbacks.onToggleShuffle!();
        } else {
          await _toggleShuffle();
        }
      case SetRepeatTrayAction(:final mode):
        if (_callbacks.onSetRepeatMode != null) {
          await _callbacks.onSetRepeatMode!(mode);
        } else {
          await _audioHandler?.setRepeatMode(mode);
        }
      case SkipToQueueIndexTrayAction(:final index):
        if (_callbacks.onSkipToQueueIndex != null) {
          await _callbacks.onSkipToQueueIndex!(index);
        } else {
          await _audioHandler?.skipToQueueItem(index);
        }
      case SetSleepMinutesTrayAction(:final minutes):
        _callbacks.onSetSleepMinutes?.call(minutes);
      case SetSleepEndOfTrackTrayAction():
        _callbacks.onSetSleepEndOfTrack?.call();
      case ToggleMuteTrayAction():
        if (_callbacks.onToggleMute != null) {
          _callbacks.onToggleMute!();
        } else {
          _audioHandler?.toggleMute();
        }
      case SetVolumePercentTrayAction(:final percent):
        if (_callbacks.onSetVolumePercent != null) {
          _callbacks.onSetVolumePercent!(percent);
        } else {
          _audioHandler?.setUserVolume(percent / 100.0);
        }
      case ToggleOfflineTrayAction():
        await _callbacks.onToggleOffline?.call();
      case NavigateTrayAction(:final route):
        await _callbacks.onNavigate?.call(route);
      case ToggleWindowVisibilityTrayAction():
        if (_snapshot.isWindowVisible) {
          LinuxTrayService.hideWindow();
        } else {
          _showWindow();
        }
      case ResumeLastTrayAction():
        if (_callbacks.onResumeLast != null) {
          await _callbacks.onResumeLast!();
        } else {
          await _audioHandler?.play();
        }
      case ShuffleLikedTrayAction():
        await _callbacks.onShuffleLiked?.call();
      case QuitTrayAction():
        await _quit();
    }
  }

  void _showWindow() {
    LinuxTrayService.presentWindow();
  }

  Future<void> _quit() async {
    if (_audioHandler != null) {
      await _audioHandler!.stop();
    }
    if (_onQuit != null) {
      try {
        await _onQuit!();
      } catch (e) {
        debugPrint('Linux tray quit hook failed: $e');
      }
    }
    await LinuxSingleInstance.dispose();
    closeWindowForQuit();
  }

  Future<void> _toggleShuffle() async {
    final newMode = _snapshot.shuffleMode == AudioServiceShuffleMode.none
        ? AudioServiceShuffleMode.all
        : AudioServiceShuffleMode.none;
    await _audioHandler?.setShuffleMode(newMode);
  }

  Future<void> _sendPlayPauseAction() async {
    if (_audioHandler != null) {
      if (_snapshot.isPlaying) {
        await _audioHandler!.pause();
      } else {
        await _audioHandler!.play();
      }
    }
  }

  void dispose() {
    _menu?.dispose();
    _menu = null;
    _icon?.dispose();
    _icon = null;
  }
}

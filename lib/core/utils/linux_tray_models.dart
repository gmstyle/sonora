import 'package:audio_service/audio_service.dart';
import 'package:collection/collection.dart';

/// A single upcoming track entry displayed in the Linux tray's Up Next submenu.
class LinuxTrayQueueEntry {
  final int queueIndex;
  final String title;
  final String? artist;
  final Duration? duration;

  const LinuxTrayQueueEntry({
    required this.queueIndex,
    required this.title,
    this.artist,
    this.duration,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinuxTrayQueueEntry &&
          runtimeType == other.runtimeType &&
          queueIndex == other.queueIndex &&
          title == other.title &&
          artist == other.artist &&
          duration == other.duration;

  @override
  int get hashCode => Object.hash(queueIndex, title, artist, duration);
}

/// Immutable playback and window snapshot rendered into the Linux tray menu.
class LinuxTraySnapshot {
  final bool isPlaying;
  final String? title;
  final String? artist;
  final bool isEpisode;
  final bool isLiked;
  final AudioServiceShuffleMode shuffleMode;
  final AudioServiceRepeatMode repeatMode;
  final List<LinuxTrayQueueEntry> upNext;
  final int? sleepRemainingMinutes;
  final bool sleepUntilEndOfTrack;
  final int volumePercent;
  final bool isMuted;
  final bool isOffline;
  final bool isWindowVisible;
  final bool hasQueue;
  final bool hasLikedSongs;

  const LinuxTraySnapshot({
    this.isPlaying = false,
    this.title,
    this.artist,
    this.isEpisode = false,
    this.isLiked = false,
    this.shuffleMode = AudioServiceShuffleMode.none,
    this.repeatMode = AudioServiceRepeatMode.none,
    this.upNext = const [],
    this.sleepRemainingMinutes,
    this.sleepUntilEndOfTrack = false,
    this.volumePercent = 100,
    this.isMuted = false,
    this.isOffline = false,
    this.isWindowVisible = true,
    this.hasQueue = false,
    this.hasLikedSongs = false,
  });

  bool get hasActiveTrack => title != null && title!.isNotEmpty;

  LinuxTraySnapshot copyWith({
    bool? isPlaying,
    String? title,
    String? artist,
    bool clearTrack = false,
    bool? isEpisode,
    bool? isLiked,
    AudioServiceShuffleMode? shuffleMode,
    AudioServiceRepeatMode? repeatMode,
    List<LinuxTrayQueueEntry>? upNext,
    int? sleepRemainingMinutes,
    bool clearSleepRemaining = false,
    bool? sleepUntilEndOfTrack,
    int? volumePercent,
    bool? isMuted,
    bool? isOffline,
    bool? isWindowVisible,
    bool? hasQueue,
    bool? hasLikedSongs,
  }) {
    return LinuxTraySnapshot(
      isPlaying: isPlaying ?? this.isPlaying,
      title: clearTrack ? null : (title ?? this.title),
      artist: clearTrack ? null : (artist ?? this.artist),
      isEpisode: isEpisode ?? this.isEpisode,
      isLiked: isLiked ?? this.isLiked,
      shuffleMode: shuffleMode ?? this.shuffleMode,
      repeatMode: repeatMode ?? this.repeatMode,
      upNext: upNext ?? this.upNext,
      sleepRemainingMinutes: clearSleepRemaining
          ? null
          : (sleepRemainingMinutes ?? this.sleepRemainingMinutes),
      sleepUntilEndOfTrack: sleepUntilEndOfTrack ?? this.sleepUntilEndOfTrack,
      volumePercent: volumePercent ?? this.volumePercent,
      isMuted: isMuted ?? this.isMuted,
      isOffline: isOffline ?? this.isOffline,
      isWindowVisible: isWindowVisible ?? this.isWindowVisible,
      hasQueue: hasQueue ?? this.hasQueue,
      hasLikedSongs: hasLikedSongs ?? this.hasLikedSongs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinuxTraySnapshot &&
          runtimeType == other.runtimeType &&
          isPlaying == other.isPlaying &&
          title == other.title &&
          artist == other.artist &&
          isEpisode == other.isEpisode &&
          isLiked == other.isLiked &&
          shuffleMode == other.shuffleMode &&
          repeatMode == other.repeatMode &&
          const ListEquality<LinuxTrayQueueEntry>().equals(
            upNext,
            other.upNext,
          ) &&
          sleepRemainingMinutes == other.sleepRemainingMinutes &&
          sleepUntilEndOfTrack == other.sleepUntilEndOfTrack &&
          volumePercent == other.volumePercent &&
          isMuted == other.isMuted &&
          isOffline == other.isOffline &&
          isWindowVisible == other.isWindowVisible &&
          hasQueue == other.hasQueue &&
          hasLikedSongs == other.hasLikedSongs;

  @override
  int get hashCode => Object.hash(
    isPlaying,
    title,
    artist,
    isEpisode,
    isLiked,
    shuffleMode,
    repeatMode,
    const ListEquality<LinuxTrayQueueEntry>().hash(upNext),
    sleepRemainingMinutes,
    sleepUntilEndOfTrack,
    volumePercent,
    isMuted,
    isOffline,
    isWindowVisible,
    hasQueue,
    hasLikedSongs,
  );
}

/// Localized labels used to construct the Linux DBusMenu and tray tooltip.
class LinuxTrayLabels {
  final String playing;
  final String paused;
  final String episode;
  final String offline;
  final String nothingPlaying;
  final String play;
  final String pause;
  final String previous;
  final String next;
  final String likeTrack;
  final String saveEpisode;
  final String shuffle;
  final String repeat;
  final String repeatOff;
  final String repeatAll;
  final String repeatOne;
  final String upNext;
  final String sleepTimer;
  final String sleepOff;
  final String sleepEndOfTrack;
  final String sleepEndOfEpisode;
  final String Function(int minutes) sleepMinutes;
  final String volume;
  final String mute;
  final String offlineMode;
  final String quickOpen;
  final String home;
  final String search;
  final String library;
  final String downloads;
  final String settings;
  final String showWindow;
  final String hideWindow;
  final String quit;
  final String resumeLast;
  final String shuffleLiked;

  const LinuxTrayLabels({
    required this.playing,
    required this.paused,
    required this.episode,
    required this.offline,
    required this.nothingPlaying,
    required this.play,
    required this.pause,
    required this.previous,
    required this.next,
    required this.likeTrack,
    required this.saveEpisode,
    required this.shuffle,
    required this.repeat,
    required this.repeatOff,
    required this.repeatAll,
    required this.repeatOne,
    required this.upNext,
    required this.sleepTimer,
    required this.sleepOff,
    required this.sleepEndOfTrack,
    required this.sleepEndOfEpisode,
    required this.sleepMinutes,
    required this.volume,
    required this.mute,
    required this.offlineMode,
    required this.quickOpen,
    required this.home,
    required this.search,
    required this.library,
    required this.downloads,
    required this.settings,
    required this.showWindow,
    required this.hideWindow,
    required this.quit,
    required this.resumeLast,
    required this.shuffleLiked,
  });

  static String _defaultSleepMinutes(int minutes) => '$minutes min';

  static const LinuxTrayLabels fallbackEn = LinuxTrayLabels(
    playing: 'Playing',
    paused: 'Paused',
    episode: 'Episode',
    offline: 'Offline',
    nothingPlaying: 'Nothing playing',
    play: 'Play',
    pause: 'Pause',
    previous: 'Previous',
    next: 'Next',
    likeTrack: 'Like track',
    saveEpisode: 'Save episode',
    shuffle: 'Shuffle',
    repeat: 'Repeat',
    repeatOff: 'Off',
    repeatAll: 'All',
    repeatOne: 'One',
    upNext: 'Up Next',
    sleepTimer: 'Sleep timer',
    sleepOff: 'Off',
    sleepEndOfTrack: 'End of track',
    sleepEndOfEpisode: 'End of episode',
    sleepMinutes: _defaultSleepMinutes,
    volume: 'Volume',
    mute: 'Mute audio',
    offlineMode: 'Offline mode',
    quickOpen: 'Go to',
    home: 'Home',
    search: 'Search',
    library: 'Library',
    downloads: 'Downloads',
    settings: 'Settings',
    showWindow: 'Show Sonora',
    hideWindow: 'Hide to tray',
    quit: 'Quit Sonora',
    resumeLast: 'Resume playback',
    shuffleLiked: 'Shuffle liked songs',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinuxTrayLabels &&
          runtimeType == other.runtimeType &&
          playing == other.playing &&
          paused == other.paused &&
          episode == other.episode &&
          offline == other.offline &&
          nothingPlaying == other.nothingPlaying &&
          play == other.play &&
          pause == other.pause &&
          previous == other.previous &&
          next == other.next &&
          likeTrack == other.likeTrack &&
          saveEpisode == other.saveEpisode &&
          shuffle == other.shuffle &&
          repeat == other.repeat &&
          repeatOff == other.repeatOff &&
          repeatAll == other.repeatAll &&
          repeatOne == other.repeatOne &&
          upNext == other.upNext &&
          sleepTimer == other.sleepTimer &&
          sleepOff == other.sleepOff &&
          sleepEndOfTrack == other.sleepEndOfTrack &&
          sleepEndOfEpisode == other.sleepEndOfEpisode &&
          sleepMinutes(15) == other.sleepMinutes(15) &&
          volume == other.volume &&
          mute == other.mute &&
          offlineMode == other.offlineMode &&
          quickOpen == other.quickOpen &&
          home == other.home &&
          search == other.search &&
          library == other.library &&
          downloads == other.downloads &&
          settings == other.settings &&
          showWindow == other.showWindow &&
          hideWindow == other.hideWindow &&
          quit == other.quit &&
          resumeLast == other.resumeLast &&
          shuffleLiked == other.shuffleLiked;

  @override
  int get hashCode => Object.hashAll([
    playing,
    paused,
    episode,
    offline,
    nothingPlaying,
    play,
    pause,
    previous,
    next,
    likeTrack,
    saveEpisode,
    shuffle,
    repeat,
    repeatOff,
    repeatAll,
    repeatOne,
    upNext,
    sleepTimer,
    sleepOff,
    sleepEndOfTrack,
    sleepEndOfEpisode,
    sleepMinutes(15),
    volume,
    mute,
    offlineMode,
    quickOpen,
    home,
    search,
    library,
    downloads,
    settings,
    showWindow,
    hideWindow,
    quit,
    resumeLast,
    shuffleLiked,
  ]);
}

/// Actions dispatched when a Linux tray menu item is activated.
sealed class LinuxTrayAction {
  const LinuxTrayAction();
}

final class OpenNowPlayingTrayAction extends LinuxTrayAction {
  const OpenNowPlayingTrayAction();
}

final class PlayPauseTrayAction extends LinuxTrayAction {
  const PlayPauseTrayAction();
}

final class PreviousTrayAction extends LinuxTrayAction {
  const PreviousTrayAction();
}

final class NextTrayAction extends LinuxTrayAction {
  const NextTrayAction();
}

final class ToggleLikeTrayAction extends LinuxTrayAction {
  const ToggleLikeTrayAction();
}

final class ToggleShuffleTrayAction extends LinuxTrayAction {
  const ToggleShuffleTrayAction();
}

final class SetRepeatTrayAction extends LinuxTrayAction {
  final AudioServiceRepeatMode mode;
  const SetRepeatTrayAction(this.mode);
}

final class SkipToQueueIndexTrayAction extends LinuxTrayAction {
  final int index;
  const SkipToQueueIndexTrayAction(this.index);
}

final class SetSleepMinutesTrayAction extends LinuxTrayAction {
  final int? minutes;
  const SetSleepMinutesTrayAction(this.minutes);
}

final class SetSleepEndOfTrackTrayAction extends LinuxTrayAction {
  const SetSleepEndOfTrackTrayAction();
}

final class ToggleMuteTrayAction extends LinuxTrayAction {
  const ToggleMuteTrayAction();
}

final class SetVolumePercentTrayAction extends LinuxTrayAction {
  final int percent;
  const SetVolumePercentTrayAction(this.percent);
}

final class ToggleOfflineTrayAction extends LinuxTrayAction {
  const ToggleOfflineTrayAction();
}

final class NavigateTrayAction extends LinuxTrayAction {
  final String route;
  const NavigateTrayAction(this.route);
}

final class ToggleWindowVisibilityTrayAction extends LinuxTrayAction {
  const ToggleWindowVisibilityTrayAction();
}

final class ResumeLastTrayAction extends LinuxTrayAction {
  const ResumeLastTrayAction();
}

final class ShuffleLikedTrayAction extends LinuxTrayAction {
  const ShuffleLikedTrayAction();
}

final class QuitTrayAction extends LinuxTrayAction {
  const QuitTrayAction();
}

enum LinuxTrayMenuItemKind { normal, checkbox, radio, separator, submenu }

/// Declarative DBusMenu item node produced by [buildLinuxTrayMenuSpec].
class LinuxTrayMenuEntry {
  final LinuxTrayMenuItemKind kind;
  final String label;
  final bool enabled;
  final bool checked;
  final int? radioGroup;
  final LinuxTrayAction? action;
  final List<LinuxTrayMenuEntry> children;

  const LinuxTrayMenuEntry._({
    required this.kind,
    this.label = '',
    this.enabled = true,
    this.checked = false,
    this.radioGroup,
    this.action,
    this.children = const [],
  });

  const LinuxTrayMenuEntry.separator()
    : this._(kind: LinuxTrayMenuItemKind.separator);

  const LinuxTrayMenuEntry.normal({
    required String label,
    bool enabled = true,
    LinuxTrayAction? action,
  }) : this._(
         kind: LinuxTrayMenuItemKind.normal,
         label: label,
         enabled: enabled,
         action: action,
       );

  const LinuxTrayMenuEntry.checkbox({
    required String label,
    required bool checked,
    bool enabled = true,
    LinuxTrayAction? action,
  }) : this._(
         kind: LinuxTrayMenuItemKind.checkbox,
         label: label,
         enabled: enabled,
         checked: checked,
         action: action,
       );

  const LinuxTrayMenuEntry.radio({
    required String label,
    required bool checked,
    required int radioGroup,
    bool enabled = true,
    LinuxTrayAction? action,
  }) : this._(
         kind: LinuxTrayMenuItemKind.radio,
         label: label,
         enabled: enabled,
         checked: checked,
         radioGroup: radioGroup,
         action: action,
       );

  const LinuxTrayMenuEntry.submenu({
    required String label,
    required List<LinuxTrayMenuEntry> children,
    bool enabled = true,
  }) : this._(
         kind: LinuxTrayMenuItemKind.submenu,
         label: label,
         enabled: enabled,
         children: children,
       );
}

String _truncateTrayText(String value, {int max = 42}) {
  if (value.length <= max) return value;
  return '${value.substring(0, max - 1)}…';
}

String _repeatSummary(AudioServiceRepeatMode mode, LinuxTrayLabels l) {
  return switch (mode) {
    AudioServiceRepeatMode.one => l.repeatOne,
    AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => l.repeatAll,
    AudioServiceRepeatMode.none => l.repeatOff,
  };
}

String _sleepSummary(LinuxTraySnapshot s, LinuxTrayLabels l) {
  if (s.sleepUntilEndOfTrack) {
    return s.isEpisode ? l.sleepEndOfEpisode : l.sleepEndOfTrack;
  }
  if (s.sleepRemainingMinutes != null) {
    return l.sleepMinutes(s.sleepRemainingMinutes!);
  }
  return l.sleepOff;
}

/// Builds the full Linux DBusMenu specification from [s] and [l].
List<LinuxTrayMenuEntry> buildLinuxTrayMenuSpec(
  LinuxTraySnapshot s,
  LinuxTrayLabels l,
) {
  final entries = <LinuxTrayMenuEntry>[];

  // 1. Header
  if (s.hasActiveTrack) {
    final trackLabel = s.artist != null && s.artist!.isNotEmpty
        ? '${s.title!} — ${s.artist!}'
        : s.title!;
    entries.add(
      LinuxTrayMenuEntry.normal(
        label: _truncateTrayText(trackLabel),
        action: const OpenNowPlayingTrayAction(),
      ),
    );
    final statusParts = <String>[
      s.isPlaying ? l.playing : l.paused,
      if (s.isEpisode) l.episode,
      if (s.isOffline) l.offline,
    ];
    entries.add(
      LinuxTrayMenuEntry.normal(label: statusParts.join(' · '), enabled: false),
    );
  } else {
    final idleLabel = s.isOffline
        ? '${l.nothingPlaying} · ${l.offline}'
        : l.nothingPlaying;
    entries.add(LinuxTrayMenuEntry.normal(label: idleLabel, enabled: false));
  }

  entries.add(const LinuxTrayMenuEntry.separator());

  // 2. Transport or idle shortcuts
  if (!s.hasActiveTrack) {
    entries.add(
      LinuxTrayMenuEntry.normal(
        label: l.resumeLast,
        enabled: s.hasQueue,
        action: const ResumeLastTrayAction(),
      ),
    );
    entries.add(
      LinuxTrayMenuEntry.normal(
        label: l.shuffleLiked,
        enabled: s.hasLikedSongs,
        action: const ShuffleLikedTrayAction(),
      ),
    );
  } else {
    entries.add(
      LinuxTrayMenuEntry.normal(
        label: s.isPlaying ? l.pause : l.play,
        action: const PlayPauseTrayAction(),
      ),
    );
    entries.add(
      LinuxTrayMenuEntry.normal(
        label: l.previous,
        enabled: s.hasQueue && !s.isEpisode,
        action: const PreviousTrayAction(),
      ),
    );
    entries.add(
      LinuxTrayMenuEntry.normal(
        label: l.next,
        enabled: s.hasQueue,
        action: const NextTrayAction(),
      ),
    );
    entries.add(
      LinuxTrayMenuEntry.checkbox(
        label: s.isEpisode ? l.saveEpisode : l.likeTrack,
        checked: s.isLiked,
        action: const ToggleLikeTrayAction(),
      ),
    );
  }

  entries.add(const LinuxTrayMenuEntry.separator());

  // 3. Playback modes, queue, sleep timer, volume, offline
  entries.add(
    LinuxTrayMenuEntry.checkbox(
      label: l.shuffle,
      checked: s.shuffleMode == AudioServiceShuffleMode.all,
      enabled: s.hasActiveTrack && !s.isEpisode,
      action: const ToggleShuffleTrayAction(),
    ),
  );

  entries.add(
    LinuxTrayMenuEntry.submenu(
      label: '${l.repeat} (${_repeatSummary(s.repeatMode, l)})',
      enabled: s.hasActiveTrack,
      children: [
        LinuxTrayMenuEntry.radio(
          label: l.repeatOff,
          checked: s.repeatMode == AudioServiceRepeatMode.none,
          radioGroup: 1,
          action: const SetRepeatTrayAction(AudioServiceRepeatMode.none),
        ),
        LinuxTrayMenuEntry.radio(
          label: l.repeatAll,
          checked:
              s.repeatMode == AudioServiceRepeatMode.all ||
              s.repeatMode == AudioServiceRepeatMode.group,
          radioGroup: 1,
          action: const SetRepeatTrayAction(AudioServiceRepeatMode.all),
        ),
        LinuxTrayMenuEntry.radio(
          label: l.repeatOne,
          checked: s.repeatMode == AudioServiceRepeatMode.one,
          radioGroup: 1,
          action: const SetRepeatTrayAction(AudioServiceRepeatMode.one),
        ),
      ],
    ),
  );

  final upNextCount = s.upNext.length;
  entries.add(
    LinuxTrayMenuEntry.submenu(
      label: upNextCount > 0 ? '${l.upNext} ($upNextCount)' : l.upNext,
      enabled: upNextCount > 0,
      children: [
        for (var i = 0; i < s.upNext.length; i++)
          LinuxTrayMenuEntry.normal(
            label: _truncateTrayText(
              '${i + 1}. ${s.upNext[i].title}'
              '${s.upNext[i].artist != null && s.upNext[i].artist!.isNotEmpty ? ' — ${s.upNext[i].artist}' : ''}',
            ),
            action: SkipToQueueIndexTrayAction(s.upNext[i].queueIndex),
          ),
      ],
    ),
  );

  final endLabel = s.isEpisode ? l.sleepEndOfEpisode : l.sleepEndOfTrack;
  final sleepOffChecked =
      !s.sleepUntilEndOfTrack && s.sleepRemainingMinutes == null;
  final activeMinutes = s.sleepRemainingMinutes;
  const sleepPresets = [15, 30, 60];
  final hasCustomMinutes =
      activeMinutes != null && !sleepPresets.contains(activeMinutes);
  entries.add(
    LinuxTrayMenuEntry.submenu(
      label: '${l.sleepTimer} (${_sleepSummary(s, l)})',
      children: [
        LinuxTrayMenuEntry.radio(
          label: l.sleepOff,
          checked: sleepOffChecked,
          radioGroup: 2,
          action: const SetSleepMinutesTrayAction(null),
        ),
        LinuxTrayMenuEntry.radio(
          label: endLabel,
          checked: s.sleepUntilEndOfTrack,
          radioGroup: 2,
          action: const SetSleepEndOfTrackTrayAction(),
        ),
        if (hasCustomMinutes)
          LinuxTrayMenuEntry.radio(
            label: l.sleepMinutes(activeMinutes),
            checked: true,
            radioGroup: 2,
            action: SetSleepMinutesTrayAction(activeMinutes),
          ),
        for (final mins in sleepPresets)
          LinuxTrayMenuEntry.radio(
            label: l.sleepMinutes(mins),
            checked: !s.sleepUntilEndOfTrack && activeMinutes == mins,
            radioGroup: 2,
            action: SetSleepMinutesTrayAction(mins),
          ),
      ],
    ),
  );

  final volSummary = s.isMuted ? '0%' : '${s.volumePercent}%';
  final selectedPreset = !s.isMuted
      ? const [
          100,
          75,
          50,
          25,
        ].firstWhere((p) => p == s.volumePercent, orElse: () => -1)
      : -1;
  entries.add(
    LinuxTrayMenuEntry.submenu(
      label: '${l.volume} ($volSummary)',
      children: [
        LinuxTrayMenuEntry.checkbox(
          label: l.mute,
          checked: s.isMuted,
          action: const ToggleMuteTrayAction(),
        ),
        const LinuxTrayMenuEntry.separator(),
        for (final pct in const [100, 75, 50, 25])
          LinuxTrayMenuEntry.radio(
            label: '$pct%',
            checked: selectedPreset == pct,
            radioGroup: 3,
            action: SetVolumePercentTrayAction(pct),
          ),
      ],
    ),
  );

  entries.add(
    LinuxTrayMenuEntry.checkbox(
      label: l.offlineMode,
      checked: s.isOffline,
      action: const ToggleOfflineTrayAction(),
    ),
  );

  entries.add(const LinuxTrayMenuEntry.separator());

  // 4. Quick open, window visibility, quit
  entries.add(
    LinuxTrayMenuEntry.submenu(
      label: l.quickOpen,
      children: [
        LinuxTrayMenuEntry.normal(
          label: l.home,
          action: const NavigateTrayAction('/'),
        ),
        LinuxTrayMenuEntry.normal(
          label: l.search,
          enabled: !s.isOffline,
          action: const NavigateTrayAction('/search'),
        ),
        LinuxTrayMenuEntry.normal(
          label: l.library,
          action: const NavigateTrayAction('/library'),
        ),
        LinuxTrayMenuEntry.normal(
          label: l.downloads,
          action: const NavigateTrayAction('/downloads'),
        ),
        LinuxTrayMenuEntry.normal(
          label: l.settings,
          action: const NavigateTrayAction('/settings'),
        ),
      ],
    ),
  );

  entries.add(
    LinuxTrayMenuEntry.normal(
      label: s.isWindowVisible ? l.hideWindow : l.showWindow,
      action: const ToggleWindowVisibilityTrayAction(),
    ),
  );

  entries.add(
    LinuxTrayMenuEntry.normal(label: l.quit, action: const QuitTrayAction()),
  );

  return entries;
}

/// Builds the tray icon hover tooltip text for [s].
String buildLinuxTrayTooltip(LinuxTraySnapshot s, LinuxTrayLabels l) {
  if (!s.hasActiveTrack) {
    return s.isOffline ? 'Sonora (${l.offline})' : 'Sonora';
  }
  final glyph = s.isPlaying ? '▶' : '⏸';
  final core = s.artist != null && s.artist!.isNotEmpty
      ? '$glyph ${s.title!} — ${s.artist!}'
      : '$glyph ${s.title!}';
  final extras = <String>[
    if (s.sleepUntilEndOfTrack)
      (s.isEpisode ? l.sleepEndOfEpisode : l.sleepEndOfTrack)
    else if (s.sleepRemainingMinutes != null)
      l.sleepMinutes(s.sleepRemainingMinutes!),
    if (s.isOffline) l.offline,
  ];
  return extras.isEmpty ? core : '$core · ${extras.join(' · ')}';
}

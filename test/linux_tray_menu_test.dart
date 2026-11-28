import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/core/utils/linux_tray_models.dart';

void main() {
  const labels = LinuxTrayLabels.fallbackEn;

  group('buildLinuxTrayMenuSpec', () {
    test('renders idle menu with resume & shuffle liked shortcuts', () {
      const snapshot = LinuxTraySnapshot(
        hasQueue: true,
        hasLikedSongs: true,
        isWindowVisible: false,
      );

      final entries = buildLinuxTrayMenuSpec(snapshot, labels);

      expect(entries.first.label, 'Nothing playing');
      expect(entries.first.enabled, isFalse);

      final resume = entries.firstWhere((e) => e.label == 'Resume playback');
      expect(resume.enabled, isTrue);
      expect(resume.action, isA<ResumeLastTrayAction>());

      final shuffleLiked = entries.firstWhere(
        (e) => e.label == 'Shuffle liked songs',
      );
      expect(shuffleLiked.enabled, isTrue);
      expect(shuffleLiked.action, isA<ShuffleLikedTrayAction>());

      final showWindow = entries.firstWhere((e) => e.label == 'Show Sonora');
      expect(showWindow.action, isA<ToggleWindowVisibilityTrayAction>());
    });

    test('renders active song with like checkbox, up next, sleep, volume', () {
      const snapshot = LinuxTraySnapshot(
        isPlaying: true,
        title: 'Midnight City',
        artist: 'M83',
        isLiked: true,
        shuffleMode: AudioServiceShuffleMode.all,
        repeatMode: AudioServiceRepeatMode.one,
        upNext: [
          LinuxTrayQueueEntry(
            queueIndex: 1,
            title: 'Resonance',
            artist: 'HOME',
          ),
          LinuxTrayQueueEntry(
            queueIndex: 2,
            title: 'Nightcall',
            artist: 'Kavinsky',
          ),
        ],
        sleepRemainingMinutes: 30,
        volumePercent: 75,
        isWindowVisible: true,
        hasQueue: true,
      );

      final entries = buildLinuxTrayMenuSpec(snapshot, labels);

      expect(entries[0].label, 'Midnight City — M83');
      expect(entries[0].action, isA<OpenNowPlayingTrayAction>());
      expect(entries[1].label, 'Playing');
      expect(entries[1].enabled, isFalse);

      final pauseItem = entries.firstWhere((e) => e.label == 'Pause');
      expect(pauseItem.action, isA<PlayPauseTrayAction>());

      final likeItem = entries.firstWhere((e) => e.label == 'Like track');
      expect(likeItem.kind, LinuxTrayMenuItemKind.checkbox);
      expect(likeItem.checked, isTrue);
      expect(likeItem.action, isA<ToggleLikeTrayAction>());

      final shuffleItem = entries.firstWhere((e) => e.label == 'Shuffle');
      expect(shuffleItem.checked, isTrue);

      final repeatSub = entries.firstWhere((e) => e.label == 'Repeat (One)');
      expect(repeatSub.kind, LinuxTrayMenuItemKind.submenu);
      expect(repeatSub.children.where((c) => c.checked).single.label, 'One');

      final upNextSub = entries.firstWhere((e) => e.label == 'Up Next (2)');
      expect(upNextSub.enabled, isTrue);
      expect(upNextSub.children.length, 2);
      expect(upNextSub.children[0].label, '1. Resonance — HOME');
      expect(
        (upNextSub.children[0].action! as SkipToQueueIndexTrayAction).index,
        1,
      );

      final sleepSub = entries.firstWhere(
        (e) => e.label == 'Sleep timer (30 min)',
      );
      expect(sleepSub.children.where((c) => c.checked).single.label, '30 min');

      final volSub = entries.firstWhere((e) => e.label == 'Volume (75%)');
      expect(volSub.children.where((c) => c.checked).single.label, '75%');

      final hideItem = entries.firstWhere((e) => e.label == 'Hide to tray');
      expect(hideItem.action, isA<ToggleWindowVisibilityTrayAction>());
    });

    test(
      'adapts labels and disabled states for podcast episodes & offline',
      () {
        const snapshot = LinuxTraySnapshot(
          isPlaying: false,
          title: 'Ep. 42 — Kernel & Coffee',
          artist: 'Kernel Podcast',
          isEpisode: true,
          isLiked: false,
          sleepUntilEndOfTrack: true,
          isMuted: true,
          isOffline: true,
          hasQueue: true,
        );

        final entries = buildLinuxTrayMenuSpec(snapshot, labels);

        expect(entries[1].label, 'Paused · Episode · Offline');

        final prevItem = entries.firstWhere((e) => e.label == 'Previous');
        expect(prevItem.enabled, isFalse);

        final saveEp = entries.firstWhere((e) => e.label == 'Save episode');
        expect(saveEp.checked, isFalse);

        final shuffleItem = entries.firstWhere((e) => e.label == 'Shuffle');
        expect(shuffleItem.enabled, isFalse);

        final sleepSub = entries.firstWhere(
          (e) => e.label == 'Sleep timer (End of episode)',
        );
        expect(
          sleepSub.children.where((c) => c.checked).single.label,
          'End of episode',
        );

        final volSub = entries.firstWhere((e) => e.label == 'Volume (0%)');
        expect(volSub.children.first.label, 'Mute audio');
        expect(volSub.children.first.checked, isTrue);

        final quickOpen = entries.firstWhere((e) => e.label == 'Go to');
        final searchItem = quickOpen.children.firstWhere(
          (c) => c.label == 'Search',
        );
        expect(searchItem.enabled, isFalse);
      },
    );
  });

  group('buildLinuxTrayTooltip', () {
    test('includes playback glyph, sleep badge, and offline state', () {
      const active = LinuxTraySnapshot(
        isPlaying: true,
        title: 'Nightcall',
        artist: 'Kavinsky',
        sleepRemainingMinutes: 15,
        isOffline: true,
      );
      expect(
        buildLinuxTrayTooltip(active, labels),
        '▶ Nightcall — Kavinsky · 15 min · Offline',
      );

      const idleOffline = LinuxTraySnapshot(isOffline: true);
      expect(buildLinuxTrayTooltip(idleOffline, labels), 'Sonora (Offline)');
    });
  });
}

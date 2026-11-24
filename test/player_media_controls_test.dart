import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/l10n/app_localizations_en.dart';
import 'package:sonora/l10n/app_localizations_it.dart';
import 'package:sonora/presentation/features/player/player_media_controls.dart';

void main() {
  final en = AppLocalizationsEn();
  final it = AppLocalizationsIt();

  group('PlayerMediaControls Music mode', () {
    test('online music controls include shuffle, repeat, like, and radio in localized language', () {
      final controls = PlayerMediaControls.build(
        PlaybackState(
          playing: true,
          shuffleMode: AudioServiceShuffleMode.all,
          repeatMode: AudioServiceRepeatMode.one,
        ),
        isLiked: true,
        isEpisode: false,
        isOffline: false,
        l10n: it,
      );

      final custom = controls
          .where((c) => c.customAction != null)
          .toList(growable: false);
      expect(custom.map((c) => c.customAction!.name).toList(), [
        PlayerMediaControls.actionShuffle,
        PlayerMediaControls.actionRepeat,
        PlayerMediaControls.actionLike,
        PlayerMediaControls.actionStartRadio,
      ]);

      final radio = custom.last;
      expect(radio.label, it.aaStartRadio);
      expect(controls[1].action, MediaAction.pause);
      expect(custom[0].label, it.aaShuffleOn);
      expect(custom[1].label, it.aaRepeatOne);
      expect(custom[2].label, it.aaUnlike);
    });

    test('offline music hides Start Radio action', () {
      final controls = PlayerMediaControls.build(
        PlaybackState(playing: false),
        isLiked: false,
        isEpisode: false,
        isOffline: true,
        l10n: en,
      );

      final customNames = controls
          .map((c) => c.customAction?.name)
          .whereType<String>()
          .toList();
      expect(customNames, [
        PlayerMediaControls.actionShuffle,
        PlayerMediaControls.actionRepeat,
        PlayerMediaControls.actionLike,
      ]);
      expect(
        customNames,
        isNot(contains(PlayerMediaControls.actionStartRadio)),
      );
    });
  });

  group('PlayerMediaControls Podcast Episode mode', () {
    test('podcast controls expose rewind 10s, forward 30s, bookmark save, and speed', () {
      final controls = PlayerMediaControls.build(
        PlaybackState(playing: true),
        isLiked: false,
        isEpisode: true,
        isOffline: false,
        speed: 1.5,
        l10n: en,
      );

      final custom = controls
          .where((c) => c.customAction != null)
          .toList(growable: false);
      expect(custom.map((c) => c.customAction!.name).toList(), [
        PlayerMediaControls.actionRewind10,
        PlayerMediaControls.actionForward30,
        PlayerMediaControls.actionLike,
        PlayerMediaControls.actionCycleSpeed,
      ]);
      expect(custom[0].androidIcon, 'drawable/ic_replay_10');
      expect(custom[1].androidIcon, 'drawable/ic_forward_30');
      expect(custom[2].androidIcon, 'drawable/ic_bookmark_border');
      expect(custom[2].label, en.aaSaveEpisode);
      expect(custom[3].androidIcon, 'drawable/ic_speed');
      expect(custom[3].label, en.aaPlaybackSpeed('1.5'));
    });

    test('nextPodcastSpeed cycles 1.0 -> 1.25 -> 1.5 -> 2.0 -> 1.0', () {
      expect(PlayerMediaControls.nextPodcastSpeed(1.0), 1.25);
      expect(PlayerMediaControls.nextPodcastSpeed(1.25), 1.5);
      expect(PlayerMediaControls.nextPodcastSpeed(1.5), 2.0);
      expect(PlayerMediaControls.nextPodcastSpeed(2.0), 1.0);
    });
  });
}

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sonora/domain/models/queue_track.dart';
import 'package:sonora/domain/repositories/queue_repository.dart';
import 'package:sonora/presentation/features/player/cast_playback_controller.dart';
import 'package:sonora/presentation/features/player/external_audio_track_controller.dart';
import 'package:sonora/presentation/features/player/like_controller.dart';
import 'package:sonora/presentation/features/player/playback_intent_controller.dart';
import 'package:sonora/presentation/features/player/playback_recovery_controller.dart';
import 'package:sonora/presentation/features/player/playback_state_publisher.dart';
import 'package:sonora/presentation/features/player/playback_volume_controller.dart';
import 'package:sonora/presentation/features/player/queue_controller.dart';
import 'package:sonora/presentation/features/player/skip_navigator.dart';
import 'package:sonora/presentation/features/player/track_transition_coordinator.dart';
import 'package:sonora/presentation/features/player/track_url_resolver.dart';
import 'package:sonora/presentation/providers/cast_provider.dart';

/// Shared log so every fake can record the step it performed, which is what
/// lets these tests assert the cascade *order* rather than just its effects.
late List<String> steps;

class _FakePlayerState extends Fake implements PlayerState {
  _FakePlayerState(this.playlist, this.duration);

  @override
  final Playlist playlist;
  @override
  final Duration duration;
}

class _FakePlayer extends Fake implements Player {
  _FakePlayer(this.playlist);

  Playlist playlist;
  Duration playerDuration = Duration.zero;

  @override
  PlayerState get state => _FakePlayerState(playlist, playerDuration);
}

class _FakeExternalAudio extends Fake implements ExternalAudioTrackController {
  Media? lastMedia;
  int calls = 0;

  @override
  Future<void> attachForMedia(Media? media) async {
    calls++;
    lastMedia = media;
    steps.add('externalAudio');
  }
}

class _FakeQueueController extends Fake implements QueueController {
  bool resolving = false;

  @override
  bool get isResolvingItem => resolving;

  @override
  void syncQueue({bool isStopping = false}) => steps.add('syncQueue');
}

class _FakeSkipNavigator extends Fake implements SkipNavigator {
  @override
  void clearTarget() => steps.add('clearTarget');
}

class _FakeStatePublisher extends Fake implements PlaybackStatePublisher {
  String? emittedId;
  Duration? emittedDuration;

  @override
  String? get lastEmittedMediaItemId => emittedId;

  @override
  Duration? get lastEmittedDuration => emittedDuration;

  @override
  void updateState(
    PlaybackState Function(PlaybackState) update, {
    Duration? forcePosition,
  }) => steps.add('queueIndex');

  @override
  void noteEmittedMediaItem(MediaItem item, {QueueTrack? track}) {
    emittedId = track?.videoId;
    emittedDuration = track?.duration;
  }
}

class _FakeQueueRepo extends Fake implements QueueRepository {
  int? persistedIndex;
  String? persistedVideoId;

  @override
  Future<void> persistCurrentIndex(int index, {String? videoId}) async {
    persistedIndex = index;
    persistedVideoId = videoId;
    steps.add('persistPointer');
  }
}

class _FakeRecovery extends Fake implements PlaybackRecoveryController {
  @override
  void resetRetryCount() => steps.add('resetRetry');
}

class _FakeLike extends Fake implements LikeController {
  @override
  Future<void> checkCurrentSongLiked(String videoId) async =>
      steps.add('checkLiked');
}

class _FakeCast extends Fake implements CastPlaybackController {
  @override
  CastState? get castState => null;
}

class _FakeUrlResolver extends Fake implements TrackUrlResolver {
  int? lastIndex;

  @override
  Future<void> resolvePendingItems(int currentIndex) async {
    lastIndex = currentIndex;
    steps.add('resolve');
  }
}

class _FakeVolume extends Fake implements PlaybackVolumeController {
  @override
  void beginFadeIn() => steps.add('fadeIn');
}

MediaItem itemFor(String videoId, {Duration? duration}) => MediaItem(
  id: videoId,
  title: 'Track $videoId',
  duration: duration,
  extras: {'videoId': videoId, 'needsUrl': false},
);

Media mediaFor(MediaItem item) =>
    Media('https://example.com/${item.id}', extras: {'mediaItem': item});

void main() {
  late _FakePlayer player;
  late _FakeExternalAudio externalAudio;
  late _FakeQueueController queueController;
  late _FakeStatePublisher statePublisher;
  late _FakeQueueRepo queueRepo;
  late _FakeUrlResolver urlResolver;
  late TrackTransitionCoordinator coordinator;
  late List<MediaItem> emitted;
  late bool isStopping;

  Playlist playlistOf(List<String> ids, {int index = 0}) =>
      Playlist([for (final id in ids) mediaFor(itemFor(id))], index: index);

  setUp(() {
    steps = [];
    emitted = [];
    isStopping = false;
    player = _FakePlayer(playlistOf(const ['a']));
    externalAudio = _FakeExternalAudio();
    queueController = _FakeQueueController();
    statePublisher = _FakeStatePublisher();
    queueRepo = _FakeQueueRepo();
    urlResolver = _FakeUrlResolver();

    coordinator = TrackTransitionCoordinator(
      player: player,
      intent: PlaybackIntentController(),
      externalAudio: externalAudio,
      queueController: queueController,
      skipNavigator: _FakeSkipNavigator(),
      statePublisher: statePublisher,
      queueRepo: queueRepo,
      recoveryController: _FakeRecovery.new,
      likeController: _FakeLike(),
      castController: _FakeCast.new,
      urlResolver: urlResolver,
      volumeController: _FakeVolume(),
      currentMediaItem: () => emitted.isEmpty ? null : emitted.last,
      emitMediaItem: emitted.add,
      isStopping: () => isStopping,
      isRestoring: () => false,
    );
  });

  group('cascade order', () {
    test('runs the steps in the documented order', () {
      final playlist = playlistOf(const ['a', 'b'], index: 1);
      player.playlist = playlist;

      coordinator.onPlaylistChanged(playlist);

      expect(steps, [
        'externalAudio',
        'clearTarget',
        'queueIndex',
        'persistPointer',
        'resetRetry',
        'checkLiked',
        'resolve',
        'syncQueue',
        'fadeIn',
      ]);
    });

    test('the media item is published before the queue is synced', () {
      final playlist = playlistOf(const ['a']);
      player.playlist = playlist;

      coordinator.onPlaylistChanged(playlist);

      expect(emitted.single.id, 'a');
      expect(
        steps.indexOf('resetRetry'),
        lessThan(steps.indexOf('syncQueue')),
        reason: 'cast and persistence read the published item',
      );
    });

    test('the pointer is persisted with the playing videoId', () {
      final playlist = playlistOf(const ['a', 'b'], index: 1);
      player.playlist = playlist;

      coordinator.onPlaylistChanged(playlist);

      expect(queueRepo.persistedIndex, 1);
      expect(queueRepo.persistedVideoId, 'b');
    });
  });

  group('isStopping', () {
    test('a stop in flight suppresses the whole cascade', () {
      isStopping = true;

      coordinator.onPlaylistChanged(playlistOf(const ['a']));

      expect(steps, isEmpty);
      expect(emitted, isEmpty);
    });
  });

  group('isResolvingItem suppression', () {
    setUp(() => queueController.resolving = true);

    test('suppresses the pointer, media item, sync and fade', () {
      final playlist = playlistOf(const ['a']);
      player.playlist = playlist;

      coordinator.onPlaylistChanged(playlist);

      expect(steps, isNot(contains('clearTarget')));
      expect(steps, isNot(contains('queueIndex')));
      expect(steps, isNot(contains('persistPointer')));
      expect(steps, isNot(contains('syncQueue')));
      expect(steps, isNot(contains('fadeIn')));
      expect(emitted, isEmpty);
    });

    test('does NOT suppress the external audio attach', () {
      final playlist = playlistOf(const ['a']);
      player.playlist = playlist;

      coordinator.onPlaylistChanged(playlist);

      expect(
        steps,
        contains('externalAudio'),
        reason: 'the audio track must follow the playlist mid-resolve',
      );
    });

    test('does NOT suppress the resolver, which would stall look-ahead', () {
      final playlist = playlistOf(const ['a', 'b'], index: 1);
      player.playlist = playlist;

      coordinator.onPlaylistChanged(playlist);

      expect(steps, contains('resolve'));
      expect(urlResolver.lastIndex, 1);
    });

    test('leaves exactly the two unsuppressed steps', () {
      final playlist = playlistOf(const ['a']);
      player.playlist = playlist;

      coordinator.onPlaylistChanged(playlist);

      expect(steps, ['externalAudio', 'resolve']);
    });
  });

  group('external audio', () {
    test('detaches when the index is out of range', () {
      final playlist = playlistOf(const ['a'], index: -1);
      player.playlist = playlist;

      coordinator.onPlaylistChanged(playlist);

      expect(externalAudio.calls, 1);
      expect(externalAudio.lastMedia, isNull);
    });

    test('attaches the media at the playing index', () {
      final playlist = playlistOf(const ['a', 'b'], index: 1);
      player.playlist = playlist;

      coordinator.onPlaylistChanged(playlist);

      expect(externalAudio.lastMedia, playlist.medias[1]);
    });
  });

  group('duration stamping', () {
    test('does not stamp a stale duration on a track change', () {
      // The engine still reports the *previous* track's length here.
      player.playerDuration = const Duration(minutes: 9);
      final playlist = playlistOf(const ['a']);
      player.playlist = playlist;

      coordinator.onPlaylistChanged(playlist);

      expect(emitted.single.duration, isNull);
    });

    test('stamps the engine duration once the track is already published', () {
      final playlist = playlistOf(const ['a']);
      player.playlist = playlist;
      coordinator.onPlaylistChanged(playlist);
      emitted.clear();
      steps.clear();

      // Same track, engine now knows the real length.
      player.playerDuration = const Duration(minutes: 3);
      coordinator.onPlaylistChanged(playlist);

      expect(emitted.single.duration, const Duration(minutes: 3));
    });

    test('onDurationChanged ignores a zero duration', () {
      coordinator.onDurationChanged(Duration.zero);
      expect(emitted, isEmpty);
    });

    test(
      'onDurationChanged binds to the playing track, not the published one',
      () {
        // Resolve suppressed the media-item update across a skip, so nothing has
        // been published yet while the player already sits on 'b'.
        player.playlist = playlistOf(const ['a', 'b'], index: 1);

        coordinator.onDurationChanged(const Duration(minutes: 4));

        expect(emitted.single.id, 'b');
        expect(emitted.single.duration, const Duration(minutes: 4));
      },
    );
  });
}

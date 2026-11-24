import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/player/playback_engine.dart';
import 'package:sonora/presentation/features/player/playback_state_publisher.dart';

import 'helpers/fake_playback_engine.dart';

void main() {
  group('PlaybackStatePublisher.resolveProcessingState', () {
    test('empty playlist without suppressingIdle yields idle', () {
      expect(
        PlaybackStatePublisher.resolveProcessingState(
          buffering: false,
          completed: false,
          playlistEmpty: true,
          suppressingIdle: false,
        ),
        AudioProcessingState.idle,
      );
    });

    test('empty playlist while suppressingIdle yields buffering not idle', () {
      expect(
        PlaybackStatePublisher.resolveProcessingState(
          buffering: false,
          completed: false,
          playlistEmpty: true,
          suppressingIdle: true,
        ),
        AudioProcessingState.buffering,
      );
    });

    test('non-empty playlist yields ready', () {
      expect(
        PlaybackStatePublisher.resolveProcessingState(
          buffering: false,
          completed: false,
          playlistEmpty: false,
          suppressingIdle: false,
        ),
        AudioProcessingState.ready,
      );
    });

    test('buffering takes precedence over empty playlist', () {
      expect(
        PlaybackStatePublisher.resolveProcessingState(
          buffering: true,
          completed: false,
          playlistEmpty: true,
          suppressingIdle: false,
        ),
        AudioProcessingState.buffering,
      );
    });

    test('completed takes precedence over empty when not buffering', () {
      expect(
        PlaybackStatePublisher.resolveProcessingState(
          buffering: false,
          completed: true,
          playlistEmpty: true,
          suppressingIdle: false,
        ),
        AudioProcessingState.completed,
      );
    });
  });

  group('PlaybackStatePublisher.publishState error clearing', () {
    test('clears stale errorMessage even when processing and playing remain ready/true', () {
      final engine = FakePlaybackEngine(
        playing: true,
        buffering: false,
        completed: false,
        playlist: const EnginePlaylist(
          index: 0,
          medias: [EngineMedia(uri: 'https://example.com/a.m4a')],
        ),
      );
      var state = PlaybackState(
        processingState: AudioProcessingState.loading,
        playing: false,
      );

      final publisher = PlaybackStatePublisher(
        engine: engine,
        getPlaybackState: () => state,
        setPlaybackState: (next) => state = next,
        isCastConnected: () => false,
        isRestoring: () => false,
        isResolving: () => false,
        savedPosition: () => Duration.zero,
        isLiked: () => false,
        onBecameReady: () {},
      );

      publisher.updatePlaybackState();
      expect(state.processingState, AudioProcessingState.ready);
      expect(state.playing, isTrue);

      state = state.copyWith(errorMessage: 'Network error');
      expect(state.errorMessage, 'Network error');

      publisher.updatePlaybackState();
      expect(state.errorMessage, isNull);
    });
  });
}

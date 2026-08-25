import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/player/playback_state_publisher.dart';

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
}

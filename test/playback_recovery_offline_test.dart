import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/queue_track.dart';
import 'package:sonora/presentation/features/player/playback_recovery_controller.dart';

void main() {
  group('PlaybackRecoveryController.isLibraryDownloadTrack', () {
    test('accepts library file:// downloads', () {
      const track = QueueTrack(
        videoId: 'vid1',
        title: 'Song',
        url: 'file:///storage/Sonora/vid1.mp3',
      );
      expect(PlaybackRecoveryController.isLibraryDownloadTrack(track), isTrue);
    });

    test('rejects transparent media-cache URIs', () {
      const track = QueueTrack(
        videoId: 'vid1',
        title: 'Song',
        url: 'file:///tmp/sonora_media_cache/vid1.webm',
      );
      expect(PlaybackRecoveryController.isLibraryDownloadTrack(track), isFalse);
    });

    test('rejects remote / unresolved tracks', () {
      const remote = QueueTrack(
        videoId: 'vid1',
        title: 'Song',
        url: 'https://example.com/a.mp3',
      );
      const pending = QueueTrack(
        videoId: 'vid1',
        title: 'Song',
        needsUrl: true,
      );
      expect(
        PlaybackRecoveryController.isLibraryDownloadTrack(remote),
        isFalse,
      );
      expect(
        PlaybackRecoveryController.isLibraryDownloadTrack(pending),
        isFalse,
      );
    });
  });
}

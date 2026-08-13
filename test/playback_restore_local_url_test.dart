import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/queue_track.dart';
import 'package:sonora/presentation/features/player/playback_restore_controller.dart';

void main() {
  group('PlaybackRestoreController.keepLocalUrlOnRestore', () {
    test('rejects media-cache files for video tracks in video mode', () {
      const track = QueueTrack(
        videoId: 'vid',
        title: 'Video',
        isVideo: true,
        url: 'file:///tmp/sonora_media_cache/vid.webm',
      );
      expect(
        PlaybackRestoreController.keepLocalUrlOnRestore(
          track: track,
          enableVideoPlayback: true,
        ),
        isFalse,
      );
    });

    test('keeps media-cache files when video playback is off', () async {
      final cacheDir = Directory(
        '${Directory.systemTemp.path}/sonora_media_cache',
      );
      await cacheDir.create(recursive: true);
      final file = File('${cacheDir.path}/vid_restore_test.webm');
      await file.writeAsBytes(const [1, 2, 3]);
      addTearDown(() async {
        if (await file.exists()) await file.delete();
      });

      final track = QueueTrack(
        videoId: 'vid',
        title: 'Video',
        isVideo: true,
        url: file.uri.toString(),
      );
      expect(
        PlaybackRestoreController.keepLocalUrlOnRestore(
          track: track,
          enableVideoPlayback: false,
        ),
        isTrue,
      );
    });

    test('rejects non-file URLs', () {
      const track = QueueTrack(
        videoId: 'vid',
        title: 'Remote',
        url: 'https://googlevideo.com/v',
      );
      expect(
        PlaybackRestoreController.keepLocalUrlOnRestore(
          track: track,
          enableVideoPlayback: false,
        ),
        isFalse,
      );
    });
  });
}

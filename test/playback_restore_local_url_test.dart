import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/domain/models/queue_track.dart';
import 'package:sonora/presentation/features/player/playback_restore_controller.dart';

void main() {
  group('PlaybackRestoreController.keepLocalUrlOnRestore', () {
    test('keeps muxed media-cache files for video tracks', () async {
      final cacheDir = Directory(
        '${Directory.systemTemp.path}/sonora_media_cache',
      );
      await cacheDir.create(recursive: true);
      final file = File('${cacheDir.path}/vid_restore_test.mp4');
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
          track,
          enableVideoPlayback: true,
        ),
        isTrue,
      );
    });

    test('rejects audio webm media-cache for video tracks in video mode', () {
      const track = QueueTrack(
        videoId: 'vid',
        title: 'Video',
        isVideo: true,
        url: 'file:///tmp/sonora_media_cache/vid.webm',
      );
      expect(
        PlaybackRestoreController.keepLocalUrlOnRestore(
          track,
          enableVideoPlayback: true,
        ),
        isFalse,
      );
    });

    test('keeps media-cache files for audio tracks', () async {
      final cacheDir = Directory(
        '${Directory.systemTemp.path}/sonora_media_cache',
      );
      await cacheDir.create(recursive: true);
      final file = File('${cacheDir.path}/song_restore_test.webm');
      await file.writeAsBytes(const [1, 2, 3]);
      addTearDown(() async {
        if (await file.exists()) await file.delete();
      });

      final track = QueueTrack(
        videoId: 'song',
        title: 'Song',
        url: file.uri.toString(),
      );
      expect(
        PlaybackRestoreController.keepLocalUrlOnRestore(
          track,
          enableVideoPlayback: false,
        ),
        isTrue,
      );
    });

    test('keeps video-only cache when sibling audio exists', () async {
      final cacheDir = Directory(
        '${Directory.systemTemp.path}/sonora_media_cache',
      );
      await cacheDir.create(recursive: true);
      final video = File('${cacheDir.path}/vid_pair_restore.v.mp4');
      final audio = File('${cacheDir.path}/vid_pair_restore.webm');
      await video.writeAsBytes(const [1, 2, 3]);
      await audio.writeAsBytes(const [4, 5, 6]);
      addTearDown(() async {
        if (await video.exists()) await video.delete();
        if (await audio.exists()) await audio.delete();
      });

      final track = QueueTrack(
        videoId: 'vid',
        title: 'Video',
        isVideo: true,
        url: video.uri.toString(),
      );
      expect(
        PlaybackRestoreController.keepLocalUrlOnRestore(
          track,
          enableVideoPlayback: true,
        ),
        isTrue,
      );
    });

    test('rejects video-only cache without sibling audio', () {
      const track = QueueTrack(
        videoId: 'vid',
        title: 'Video',
        isVideo: true,
        url: 'file:///tmp/sonora_media_cache/vid_orphan.v.mp4',
      );
      expect(
        PlaybackRestoreController.keepLocalUrlOnRestore(
          track,
          enableVideoPlayback: true,
        ),
        isFalse,
      );
    });

    test('rejects video-only cache in audio mode', () {
      const track = QueueTrack(
        videoId: 'vid',
        title: 'Video',
        isVideo: true,
        url: 'file:///tmp/sonora_media_cache/vid.v.mp4',
      );
      expect(
        PlaybackRestoreController.keepLocalUrlOnRestore(
          track,
          enableVideoPlayback: false,
        ),
        isFalse,
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
          track,
          enableVideoPlayback: false,
        ),
        isFalse,
      );
    });
  });
}

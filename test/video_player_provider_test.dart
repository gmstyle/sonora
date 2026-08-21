import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/providers/video_player_provider.dart';

void main() {
  group('shouldAttachVideoController', () {
    test(
      'returns true only when video playback is enabled and track is video',
      () {
        expect(
          shouldAttachVideoController(
            enableVideoPlayback: true,
            isVideoTrack: true,
          ),
          isTrue,
        );
      },
    );

    test('returns false when video playback is disabled', () {
      expect(
        shouldAttachVideoController(
          enableVideoPlayback: false,
          isVideoTrack: true,
        ),
        isFalse,
      );
    });

    test('returns false when track is not video', () {
      expect(
        shouldAttachVideoController(
          enableVideoPlayback: true,
          isVideoTrack: false,
        ),
        isFalse,
      );
    });
  });

  group('shouldDetachVideoOnBackground', () {
    test(
      'returns true only on Android with enabled video and active session',
      () {
        expect(
          shouldDetachVideoOnBackground(
            isAndroid: true,
            enableVideoPlayback: true,
            hasActiveVideoSession: true,
          ),
          isTrue,
        );
      },
    );

    test('returns false when not Android', () {
      expect(
        shouldDetachVideoOnBackground(
          isAndroid: false,
          enableVideoPlayback: true,
          hasActiveVideoSession: true,
        ),
        isFalse,
      );
    });

    test('returns false when video playback is disabled', () {
      expect(
        shouldDetachVideoOnBackground(
          isAndroid: true,
          enableVideoPlayback: false,
          hasActiveVideoSession: true,
        ),
        isFalse,
      );
    });

    test('returns false when there is no active video session', () {
      expect(
        shouldDetachVideoOnBackground(
          isAndroid: true,
          enableVideoPlayback: true,
          hasActiveVideoSession: false,
        ),
        isFalse,
      );
    });
  });

  group('shouldReplaceVideoWithShimmer', () {
    test('is true only for the first load before init', () {
      const loading = VideoPlayerState(isLoading: true);
      expect(shouldReplaceVideoWithShimmer(loading), isTrue);
    });

    test('stays false once the video surface is initialized', () {
      const switching = VideoPlayerState(
        isInitialized: true,
        isLoading: true,
        isVideoVisible: true,
      );
      expect(shouldReplaceVideoWithShimmer(switching), isFalse);
    });
  });

  group('shouldShowVideoPlayer', () {
    test('requires enable + visible + initialized', () {
      const ready = VideoPlayerState(isVideoVisible: true, isInitialized: true);
      expect(
        shouldShowVideoPlayer(enableVideoPlayback: true, videoState: ready),
        isTrue,
      );
      expect(
        shouldShowVideoPlayer(enableVideoPlayback: false, videoState: ready),
        isFalse,
      );
    });
  });
}

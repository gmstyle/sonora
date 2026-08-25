import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/presentation/features/player/android_auto_browser_controller.dart';
import 'package:sonora/presentation/features/player/playback_restore_controller.dart';

void main() {
  group('AndroidAutoBrowserController.resumptionChildrenFor', () {
    test('returns empty list when there is no current media item', () {
      expect(AndroidAutoBrowserController.resumptionChildrenFor(null), isEmpty);
    });

    test('returns the current media item for EXTRA_RECENT', () {
      final item = MediaItem(id: 'vid1', title: 'Reggae Track');
      final children = AndroidAutoBrowserController.resumptionChildrenFor(item);
      expect(children, hasLength(1));
      expect(children.single.id, 'vid1');
      expect(children.single.title, 'Reggae Track');
    });
  });

  group('PlaybackRestoreController.readyWaitTimeout', () {
    test('is long enough to cover cold restore without the old 3s abort', () {
      expect(
        PlaybackRestoreController.readyWaitTimeout,
        const Duration(seconds: 60),
      );
      expect(
        PlaybackRestoreController.readyWaitTimeout,
        greaterThan(const Duration(seconds: 3)),
      );
    });
  });
}

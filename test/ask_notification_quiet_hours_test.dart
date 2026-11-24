import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/data/services/ask_background_scheduler.dart';
import 'package:sonora/presentation/providers/ask_notification_service.dart';

void main() {
  group('computeDropDeliveryTime', () {
    test('returns null during daytime hours (09:00 .. 21:59)', () {
      expect(computeDropDeliveryTime(DateTime(2026, 11, 24, 9, 0)), isNull);
      expect(computeDropDeliveryTime(DateTime(2026, 11, 24, 14, 30)), isNull);
      expect(computeDropDeliveryTime(DateTime(2026, 11, 24, 21, 59)), isNull);
    });

    test('defers late evening (22:00+) to next day at 09:30', () {
      expect(
        computeDropDeliveryTime(DateTime(2026, 11, 24, 22, 0)),
        DateTime(2026, 11, 25, 9, 30),
      );
      expect(
        computeDropDeliveryTime(DateTime(2026, 11, 24, 23, 45)),
        DateTime(2026, 11, 25, 9, 30),
      );
    });

    test('defers early morning (00:00 .. 08:59) to same day at 09:30', () {
      expect(
        computeDropDeliveryTime(DateTime(2026, 11, 24, 0, 15)),
        DateTime(2026, 11, 24, 9, 30),
      );
      expect(
        computeDropDeliveryTime(DateTime(2026, 11, 24, 8, 59)),
        DateTime(2026, 11, 24, 9, 30),
      );
    });

    test('returns null when quietHoursStart == quietHoursEnd', () {
      expect(
        computeDropDeliveryTime(
          DateTime(2026, 11, 24, 23, 0),
          quietStartHour: 0,
          quietEndHour: 0,
        ),
        isNull,
      );
    });
  });

  group('shouldRunAskBackgroundSync', () {
    test(
      'enabled only when non-TV, online, drops+notifications+taste enabled',
      () {
        expect(
          shouldRunAskBackgroundSync(
            askDropsEnabled: true,
            askNotificationsEnabled: true,
            askUseTasteContext: true,
            offlineMode: false,
            isAndroidTv: false,
          ),
          isTrue,
        );

        expect(
          shouldRunAskBackgroundSync(
            askDropsEnabled: true,
            askNotificationsEnabled: true,
            askUseTasteContext: true,
            offlineMode: false,
            isAndroidTv: true,
          ),
          isFalse,
        );

        expect(
          shouldRunAskBackgroundSync(
            askDropsEnabled: true,
            askNotificationsEnabled: false,
            askUseTasteContext: true,
            offlineMode: false,
            isAndroidTv: false,
          ),
          isFalse,
        );

        expect(
          shouldRunAskBackgroundSync(
            askDropsEnabled: true,
            askNotificationsEnabled: true,
            askUseTasteContext: false,
            offlineMode: false,
            isAndroidTv: false,
          ),
          isFalse,
        );

        expect(
          shouldRunAskBackgroundSync(
            askDropsEnabled: true,
            askNotificationsEnabled: true,
            askUseTasteContext: true,
            offlineMode: true,
            isAndroidTv: false,
          ),
          isFalse,
        );
      },
    );
  });
}

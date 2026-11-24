import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/utils/notification_utils.dart';
import '../../core/utils/platform_utils.dart';
import '../../domain/models/ask_chat_models.dart';

const kAskDropNotificationId = 72001;
const kAskDropPayloadPrefix = 'ask_drop:';

/// Set from the app widget so notification taps route to `/ask?dropId=...`.
void Function(String dropId)? askDropNotificationHandler;

bool _tzInitialized = false;

void _ensureTimeZonesInitialized() {
  if (_tzInitialized) return;
  tz_data.initializeTimeZones();
  _tzInitialized = true;
}

/// Returns `null` when [now] is outside quiet hours so delivery is immediate,
/// or the next local delivery [DateTime] when [now] falls inside quiet hours.
DateTime? computeDropDeliveryTime(
  DateTime now, {
  int quietStartHour = 22,
  int quietEndHour = 9,
  int deliveryMinute = 30,
}) {
  if (quietStartHour == quietEndHour) return null;

  final isQuiet = quietStartHour > quietEndHour
      ? (now.hour >= quietStartHour || now.hour < quietEndHour)
      : (now.hour >= quietStartHour && now.hour < quietEndHour);

  if (!isQuiet) return null;

  final targetDay =
      (quietStartHour > quietEndHour && now.hour >= quietStartHour)
      ? DateTime(now.year, now.month, now.day + 1)
      : DateTime(now.year, now.month, now.day);

  return DateTime(
    targetDay.year,
    targetDay.month,
    targetDay.day,
    quietEndHour,
    deliveryMinute,
  );
}

final askNotificationServiceProvider = Provider<AskNotificationService>((ref) {
  return const FlutterAskNotificationService();
});

abstract class AskNotificationService {
  Future<void> showDrop(AskProactiveDrop drop);

  Future<void> showOrScheduleDrop(
    AskProactiveDrop drop, {
    int quietStartHour = 22,
    int quietEndHour = 9,
    DateTime? now,
  });
}

class FlutterAskNotificationService implements AskNotificationService {
  const FlutterAskNotificationService();

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'sonora_ask_drops',
      'Sonora Ask Pulse Drops',
      channelDescription: 'Personalized music discovery highlights from Ask',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    linux: LinuxNotificationDetails(defaultActionName: 'Open Sonora Ask'),
  );

  @override
  Future<void> showDrop(AskProactiveDrop drop) async {
    await flutterLocalNotificationsPlugin.show(
      id: kAskDropNotificationId,
      title: drop.title,
      body: drop.body,
      notificationDetails: _notificationDetails,
      payload: '$kAskDropPayloadPrefix${drop.id}',
    );
  }

  @override
  Future<void> showOrScheduleDrop(
    AskProactiveDrop drop, {
    int quietStartHour = 22,
    int quietEndHour = 9,
    DateTime? now,
  }) async {
    final delivery = computeDropDeliveryTime(
      now ?? DateTime.now(),
      quietStartHour: quietStartHour,
      quietEndHour: quietEndHour,
    );
    if (delivery == null) {
      await showDrop(drop);
      return;
    }

    // On Linux there is no OS alarm queue for deferred desktop toasts; keep the
    // drop in Drift for the in-app Ask screen without waking the desktop at night.
    if (!isAndroid) return;

    _ensureTimeZonesInitialized();
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: kAskDropNotificationId,
      title: drop.title,
      body: drop.body,
      scheduledDate: tz.TZDateTime.from(delivery.toUtc(), tz.UTC),
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$kAskDropPayloadPrefix${drop.id}',
    );
  }
}

class NoOpAskNotificationService implements AskNotificationService {
  const NoOpAskNotificationService();

  @override
  Future<void> showDrop(AskProactiveDrop drop) async {}

  @override
  Future<void> showOrScheduleDrop(
    AskProactiveDrop drop, {
    int quietStartHour = 22,
    int quietEndHour = 9,
    DateTime? now,
  }) async {}
}

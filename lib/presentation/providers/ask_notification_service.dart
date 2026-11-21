import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/notification_utils.dart';
import '../../domain/models/ask_chat_models.dart';

const kAskDropNotificationId = 72001;
const kAskDropPayloadPrefix = 'ask_drop:';

/// Set from the app widget so notification taps route to `/ask?dropId=...`.
void Function(String dropId)? askDropNotificationHandler;

final askNotificationServiceProvider = Provider<AskNotificationService>((ref) {
  return const FlutterAskNotificationService();
});

abstract class AskNotificationService {
  Future<void> showDrop(AskProactiveDrop drop);
}

class FlutterAskNotificationService implements AskNotificationService {
  const FlutterAskNotificationService();

  @override
  Future<void> showDrop(AskProactiveDrop drop) async {
    await flutterLocalNotificationsPlugin.show(
      id: kAskDropNotificationId,
      title: drop.title,
      body: drop.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'sonora_ask_drops',
          'Sonora Ask Pulse Drops',
          channelDescription:
              'Personalized music discovery highlights from Ask',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        linux: LinuxNotificationDetails(defaultActionName: 'Open Sonora Ask'),
      ),
      payload: '$kAskDropPayloadPrefix${drop.id}',
    );
  }
}

class NoOpAskNotificationService implements AskNotificationService {
  const NoOpAskNotificationService();

  @override
  Future<void> showDrop(AskProactiveDrop drop) async {}
}

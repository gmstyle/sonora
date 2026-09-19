import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/notification_utils.dart';
import '../../l10n/app_localizations.dart';

/// Stable notification id so progress updates replace instead of stacking.
const kDownloadNotificationId = 71001;

const kDownloadCancelAllActionId = 'download_cancel_all';
const kDownloadOpenActionId = 'download_open';

/// Set from the app widget so notification taps/actions reach Riverpod.
void Function(String actionId)? downloadNotificationActionHandler;

final downloadNotificationServiceProvider =
    Provider<DownloadNotificationService>((ref) {
      return const FlutterDownloadNotificationService();
    });

abstract class DownloadNotificationService {
  Future<void> showProgress({
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  });

  Future<void> showCompleted({
    required String title,
    required String body,
  });

  Future<void> dismiss();
}

class FlutterDownloadNotificationService implements DownloadNotificationService {
  const FlutterDownloadNotificationService();

  @override
  Future<void> showProgress({
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  }) async {
    final l10n = lookupAppLocalizations(PlatformDispatcher.instance.locale);
    await flutterLocalNotificationsPlugin.show(
      id: kDownloadNotificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'sonora_downloads',
          'Sonora Downloads',
          channelDescription: 'Download progress',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: maxProgress,
          progress: progress.clamp(0, maxProgress),
          actions: [
            AndroidNotificationAction(
              kDownloadCancelAllActionId,
              l10n.cancelAllDownloads,
              // Bring UI to foreground so the action is delivered on the main
              // isolate where [downloadNotificationActionHandler] + Riverpod live.
              cancelNotification: false,
              showsUserInterface: true,
            ),
          ],
        ),
        linux: LinuxNotificationDetails(
          defaultActionName: 'Open Sonora',
          urgency: LinuxNotificationUrgency.low,
        ),
      ),
      payload: kDownloadOpenActionId,
    );
  }

  @override
  Future<void> showCompleted({
    required String title,
    required String body,
  }) async {
    await flutterLocalNotificationsPlugin.show(
      id: kDownloadNotificationId,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'sonora_downloads',
          'Sonora Downloads',
          channelDescription: 'Download progress',
          importance: Importance.defaultImportance,
          onlyAlertOnce: true,
        ),
        linux: LinuxNotificationDetails(defaultActionName: 'Open Sonora'),
      ),
      payload: kDownloadOpenActionId,
    );
  }

  @override
  Future<void> dismiss() async {
    await flutterLocalNotificationsPlugin.cancel(id: kDownloadNotificationId);
  }
}

class NoOpDownloadNotificationService implements DownloadNotificationService {
  const NoOpDownloadNotificationService();

  @override
  Future<void> showProgress({
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  }) async {}

  @override
  Future<void> showCompleted({
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> dismiss() async {}
}

void handleDownloadNotificationResponse(NotificationResponse response) {
  final action = response.actionId;
  if (action != null && action.isNotEmpty) {
    downloadNotificationActionHandler?.call(action);
    return;
  }
  if (response.id == kDownloadNotificationId ||
      response.payload == kDownloadOpenActionId) {
    downloadNotificationActionHandler?.call(kDownloadOpenActionId);
  }
}

/// Background isolate entry for notification actions that do not show UI.
@pragma('vm:entry-point')
void handleDownloadNotificationResponseBackground(
  NotificationResponse response,
) {
  handleDownloadNotificationResponse(response);
}

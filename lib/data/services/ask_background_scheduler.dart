import 'package:workmanager/workmanager.dart';

import '../../core/utils/platform_utils.dart';
import 'ask_background_worker.dart';

const kAskProactiveWorkUniqueName = 'sonora_ask_proactive_drop';
const kAskProactiveWorkTask = 'sonora.ask.proactive_drop';

bool shouldRunAskBackgroundSync({
  required bool askDropsEnabled,
  required bool askNotificationsEnabled,
  required bool askUseTasteContext,
  required bool offlineMode,
  required bool isAndroidTv,
}) {
  return !isAndroidTv &&
      askDropsEnabled &&
      askNotificationsEnabled &&
      askUseTasteContext &&
      !offlineMode;
}

class AskBackgroundScheduler {
  const AskBackgroundScheduler._();

  static bool _initialized = false;

  static Future<void> initialize({required bool isAndroidTv}) async {
    if (!isAndroid || isAndroidTv || _initialized) return;
    await Workmanager().initialize(askBackgroundCallbackDispatcher);
    _initialized = true;
  }

  static Future<void> syncRegistration({
    required bool enabled,
    required bool isAndroidTv,
  }) async {
    if (!isAndroid || isAndroidTv) return;
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        kAskProactiveWorkUniqueName,
        kAskProactiveWorkTask,
        frequency: const Duration(hours: 12),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
      );
    } else {
      await Workmanager().cancelByUniqueName(kAskProactiveWorkUniqueName);
    }
  }
}

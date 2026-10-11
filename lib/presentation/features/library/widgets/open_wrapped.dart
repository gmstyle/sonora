import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/settings_provider.dart';
import '../../../providers/stats_provider.dart';
import 'sonora_wrapped_view.dart';

Future<void> openSonoraWrapped(BuildContext context, WidgetRef ref) {
  final stats = ref.read(statsProvider);
  if (stats.isLoading || !stats.isWrappedAvailable) {
    return Future<void>.value();
  }
  ref.read(settingsProvider.notifier).markWrappedSeen();
  return SonoraWrappedView.show(context, stats);
}

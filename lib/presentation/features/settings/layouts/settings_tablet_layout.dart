import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/settings_split_layout.dart';

class SettingsTabletLayout extends ConsumerWidget {
  const SettingsTabletLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SettingsSplitLayout();
  }
}

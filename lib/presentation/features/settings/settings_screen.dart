import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../providers/android_tv_provider.dart';
import 'layouts/settings_mobile_layout.dart';
import 'layouts/settings_tablet_layout.dart';
import 'layouts/settings_wide_layout.dart';
import 'settings_shared.dart';
import 'widgets/settings_split_layout.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.initialCategory});

  /// When set (e.g. from `/settings?section=ask`), opens that category.
  final SettingsCategory? initialCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TV always uses the split master/detail chrome with D-pad focusables.
    if (ref.watch(isAndroidTvProvider)) {
      return SettingsSplitLayout(initialCategory: initialCategory);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kCompactBreakpoint) {
          return SettingsMobileLayout(initialCategory: initialCategory);
        } else if (constraints.maxWidth < kExpandedBreakpoint) {
          return SettingsTabletLayout(initialCategory: initialCategory);
        } else {
          return SettingsWideLayout(initialCategory: initialCategory);
        }
      },
    );
  }
}

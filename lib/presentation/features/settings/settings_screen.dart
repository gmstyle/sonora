import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import 'layouts/settings_mobile_layout.dart';
import 'layouts/settings_tablet_layout.dart';
import 'layouts/settings_wide_layout.dart';
import 'settings_shared.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.initialCategory});

  /// When set (e.g. from `/settings?section=ask`), opens that category.
  final SettingsCategory? initialCategory;

  @override
  Widget build(BuildContext context) {
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

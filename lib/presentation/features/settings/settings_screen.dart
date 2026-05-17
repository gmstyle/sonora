import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import 'layouts/settings_mobile_layout.dart';
import 'layouts/settings_tablet_layout.dart';
import 'layouts/settings_wide_layout.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < kCompactBreakpoint) {
          return const SettingsMobileLayout();
        } else if (constraints.maxWidth < kExpandedBreakpoint) {
          return const SettingsTabletLayout();
        } else {
          return const SettingsWideLayout();
        }
      },
    );
  }
}

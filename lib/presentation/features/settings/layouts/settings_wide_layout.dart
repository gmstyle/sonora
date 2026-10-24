import 'package:flutter/material.dart';

import '../settings_shared.dart';
import '../widgets/settings_split_layout.dart';

class SettingsWideLayout extends StatelessWidget {
  const SettingsWideLayout({super.key, this.initialCategory});

  final SettingsCategory? initialCategory;

  @override
  Widget build(BuildContext context) {
    return SettingsSplitLayout(initialCategory: initialCategory);
  }
}

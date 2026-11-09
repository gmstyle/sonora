import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings_shared.dart';

/// Selected Settings category in the wide and tablet split.
///
/// Lives above the layouts so a breakpoint change does not reset the pane.
class SettingsCategoryNotifier extends Notifier<SettingsCategory> {
  @override
  SettingsCategory build() => SettingsCategory.appearance;

  void select(SettingsCategory category) {
    if (state != category) state = category;
  }
}

final settingsCategoryProvider =
    NotifierProvider<SettingsCategoryNotifier, SettingsCategory>(
      SettingsCategoryNotifier.new,
    );

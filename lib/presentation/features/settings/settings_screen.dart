import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/layout_breakpoints.dart';
import '../../providers/android_tv_provider.dart';
import '../tv/screens/tv_settings_screen.dart';
import 'layouts/settings_mobile_layout.dart';
import 'layouts/settings_tablet_layout.dart';
import 'layouts/settings_wide_layout.dart';
import 'providers/settings_category_provider.dart';
import 'settings_shared.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.initialCategory});

  /// When set (e.g. from `/settings?section=ask`), opens that category.
  final SettingsCategory? initialCategory;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Consumed by the compact list once, so a later resize does not re-open it.
  SettingsCategory? _pendingDeepLinkCategory;

  @override
  void initState() {
    super.initState();
    _pendingDeepLinkCategory = widget.initialCategory;
    if (_pendingDeepLinkCategory == null) return;
    // Riverpod forbids modifying a provider in initState, so apply after the
    // first frame. The compact list reads the pending value on that frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final category = _pendingDeepLinkCategory;
      if (category != null) {
        ref.read(settingsCategoryProvider.notifier).select(category);
      }
      setState(() => _pendingDeepLinkCategory = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(isAndroidTvProvider)) {
      return const TvSettingsScreen();
    }
    final size = MediaQuery.sizeOf(context);
    // Below the tablet content split, keep the category list + push flow.
    if (isCompactShell(size) || size.width < kMediumBreakpoint) {
      return SettingsMobileLayout(initialCategory: _pendingDeepLinkCategory);
    }
    if (size.width < kExpandedBreakpoint) {
      return const SettingsTabletLayout();
    }
    return const SettingsWideLayout();
  }
}

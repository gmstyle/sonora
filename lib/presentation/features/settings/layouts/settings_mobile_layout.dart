import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../settings_screen_content.dart';
import '../settings_shared.dart';

class SettingsMobileLayout extends ConsumerStatefulWidget {
  const SettingsMobileLayout({super.key, this.initialCategory});

  final SettingsCategory? initialCategory;

  @override
  ConsumerState<SettingsMobileLayout> createState() =>
      _SettingsMobileLayoutState();
}

class _SettingsMobileLayoutState extends ConsumerState<SettingsMobileLayout> {
  bool _openedInitial = false;

  @override
  void initState() {
    super.initState();
    final category = widget.initialCategory;
    if (category == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _openedInitial) return;
      _openedInitial = true;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => SettingsCategoryScreen(category: category),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => popSettings(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.settingsLabel,
          style: theme.textTheme.titleLarge,
        ),
        centerTitle: false,
      ),
      body: const SettingsScreenContent(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../settings_screen_content.dart';
import '../settings_shared.dart';

class SettingsMobileLayout extends ConsumerWidget {
  const SettingsMobileLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

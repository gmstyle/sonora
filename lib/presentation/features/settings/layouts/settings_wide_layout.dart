import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../settings_screen_content.dart';

class SettingsWideLayout extends StatelessWidget {
  const SettingsWideLayout({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.settingsLabel,
          style: theme.textTheme.titleLarge,
        ),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: SettingsScreenContent(),
          ),
        ),
      ),
    );
  }
}

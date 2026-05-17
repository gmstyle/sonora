import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings_screen_content.dart';

class SettingsMobileLayout extends ConsumerWidget {
  const SettingsMobileLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: theme.textTheme.titleLarge),
        centerTitle: false,
      ),
      body: const SettingsScreenContent(),
    );
  }
}

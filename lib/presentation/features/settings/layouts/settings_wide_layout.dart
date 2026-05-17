import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/settings_provider.dart';
import '../settings_screen_content.dart';

class SettingsWideLayout extends ConsumerWidget {
  const SettingsWideLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: theme.textTheme.titleLarge),
        centerTitle: false,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: const SettingsScreenContent(),
            ),
          ),
          Container(
            width: 1,
            color: theme.colorScheme.outlineVariant,
          ),
          const Expanded(flex: 1, child: _InfoPanel()),
        ],
      ),
    );
  }
}

class _InfoPanel extends ConsumerWidget {
  const _InfoPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Configuration',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _infoRow(theme, 'Theme', settings.themeMode.name),
          _infoRow(
            theme,
            'Dynamic color',
            settings.useDynamicColor ? 'On' : 'Off',
          ),
          _infoRow(theme, 'AMOLED', settings.useAmoled ? 'On' : 'Off'),
          const SizedBox(height: 16),
          _infoRow(theme, 'Country', '${settings.gl} (${settings.hl})'),
          const SizedBox(height: 16),
          _infoRow(theme, 'Crossfade', '${settings.crossfadeSeconds}s'),
          _infoRow(
            theme,
            'Track history',
            settings.trackHistory ? 'On' : 'Off',
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

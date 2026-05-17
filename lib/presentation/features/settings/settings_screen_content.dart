import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../providers/export_backup_use_case_provider.dart';
import '../../providers/import_backup_use_case_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/settings_provider.dart';
import '../library/providers/library_provider.dart';
import '../search/providers/search_provider.dart';
import 'settings_shared.dart';

class SettingsScreenContent extends ConsumerWidget {
  const SettingsScreenContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      children: [
        _AppearanceSection(settings: settings, notifier: notifier),
        _ContentSection(settings: settings, notifier: notifier),
        _PlaybackSection(settings: settings, notifier: notifier),
        _DownloadSection(settings: settings, notifier: notifier),
        _PrivacySection(settings: settings, notifier: notifier, ref: ref),
        _BackupSection(ref: ref),
        _UpdatesSection(settings: settings, notifier: notifier),
        _AboutSection(),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Appearance ───────────────────────────────────────────────────

class _AppearanceSection extends StatelessWidget {
  final Settings settings;
  final SettingsNotifier notifier;

  const _AppearanceSection({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final current = settings.themeMode;
    const values = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    const labels = ['System', 'Light', 'Dark'];

    return SettingsSection(
      title: 'Appearance',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SegmentedButton<ThemeMode>(
            segments: List.generate(
              values.length,
              (i) => ButtonSegment<ThemeMode>(
                value: values[i],
                label: Text(labels[i]),
              ),
            ),
            selected: {current},
            onSelectionChanged:
                (selected) => notifier.setThemeMode(selected.first),
          ),
        ),
        if (current == ThemeMode.dark || current == ThemeMode.system)
          SettingsSwitchTile(
            title: 'AMOLED dark mode',
            subtitle: 'Use true black background',
            value: settings.useAmoled,
            onChanged: notifier.setUseAmoled,
            icon: Icons.dark_mode,
          ),
        SettingsSwitchTile(
          title: 'Dynamic color',
          subtitle: 'Adapt theme to wallpaper (Android 12+)',
          value: settings.useDynamicColor,
          onChanged: notifier.setUseDynamicColor,
          icon: Icons.palette_outlined,
        ),
      ],
    );
  }
}

// ── Content ──────────────────────────────────────────────────────

class _ContentSection extends StatelessWidget {
  final Settings settings;
  final SettingsNotifier notifier;

  const _ContentSection({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Content',
      children: [
        SettingsDropdownTile(
          title: 'Country (gl)',
          value: settings.gl,
          options: kCountryCodes,
          onChanged: (v) {
            if (v != null) notifier.setGl(v);
          },
        ),
        const Divider(height: 1),
        SettingsDropdownTile(
          title: 'Language (hl)',
          value: settings.hl,
          options: kLanguageCodes,
          onChanged: (v) {
            if (v != null) notifier.setHl(v);
          },
        ),
      ],
    );
  }
}

// ── Playback ─────────────────────────────────────────────────────

class _PlaybackSection extends StatelessWidget {
  final Settings settings;
  final SettingsNotifier notifier;

  const _PlaybackSection({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Playback',
      children: [
        SettingsSliderTile(
          title: 'Crossfade',
          subtitle: 'Duration',
          value: settings.crossfadeSeconds.toDouble(),
          min: 0,
          max: 12,
          displayValue: (v) => '${v.round()}s',
          onChanged: (v) => notifier.setCrossfadeSeconds(v.round()),
        ),
        const Divider(height: 1),
        SettingsSwitchTile(
          title: 'Restore queue on startup',
          value: settings.restoreQueueOnStartup,
          onChanged: notifier.setRestoreQueueOnStartup,
          icon: Icons.restore,
        ),
        const Divider(height: 1),
        SettingsSwitchTile(
          title: 'Auto-play Up Next',
          subtitle: 'Automatically play related content when queue ends',
          value: settings.autoPlayUpNext,
          onChanged: notifier.setAutoPlayUpNext,
          icon: Icons.playlist_play,
        ),
      ],
    );
  }
}

// ── Download ─────────────────────────────────────────────────────

class _DownloadSection extends StatelessWidget {
  final Settings settings;
  final SettingsNotifier notifier;

  const _DownloadSection({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Downloads',
      children: [
        SettingsButtonTile(
          title: 'Download folder',
          subtitle: settings.downloadPath ?? 'Default location',
          icon: Icons.folder_outlined,
          onPressed: () async {
            final path = await FilePicker.getDirectoryPath();
            if (path != null) notifier.setDownloadPath(path);
          },
        ),
        const Divider(height: 1),
        SettingsSwitchTile(
          title: 'Download only on Wi-Fi',
          value: settings.downloadOnlyOnWifi,
          onChanged: notifier.setDownloadOnlyOnWifi,
          icon: Icons.wifi,
        ),
      ],
    );
  }
}

// ── Privacy ──────────────────────────────────────────────────────

class _PrivacySection extends StatelessWidget {
  final Settings settings;
  final SettingsNotifier notifier;
  final WidgetRef ref;

  const _PrivacySection({
    required this.settings,
    required this.notifier,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Privacy',
      children: [
        SettingsSwitchTile(
          title: 'Track listening history',
          value: settings.trackHistory,
          onChanged: notifier.setTrackHistory,
          icon: Icons.history,
        ),
        const Divider(height: 1),
        SettingsButtonTile(
          title: 'Clear search history',
          icon: Icons.search_off,
          onPressed: () => _clearSearchHistory(context),
        ),
        const Divider(height: 1),
        SettingsButtonTile(
          title: 'Clear listening history',
          icon: Icons.delete_sweep,
          onPressed: () => _clearListeningHistory(context),
        ),
      ],
    );
  }

  Future<void> _clearSearchHistory(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Clear search history'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
    if (confirm == true) {
      await ref.read(libraryNotifierProvider.notifier).clearSearchHistory();
      if (context.mounted) {
        ref.invalidate(recentSearchesProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Search history cleared')));
      }
    }
  }

  Future<void> _clearListeningHistory(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Clear listening history'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
    if (confirm == true) {
      await ref.read(libraryNotifierProvider.notifier).clearHistory();
      if (context.mounted) {
        ref.invalidate(libraryHistoryProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listening history cleared')),
        );
      }
    }
  }
}

// ── Backup ───────────────────────────────────────────────────────

class _BackupSection extends StatelessWidget {
  final WidgetRef ref;

  const _BackupSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Backup & Restore',
      children: [
        SettingsButtonTile(
          title: 'Export data',
          subtitle: 'Save playlists, likes, and settings',
          icon: Icons.file_upload_outlined,
          onPressed: () => _exportData(context),
        ),
        const Divider(height: 1),
        SettingsButtonTile(
          title: 'Import data',
          subtitle: 'Restore from a backup file',
          icon: Icons.file_download_outlined,
          onPressed: () => _importData(context),
        ),
      ],
    );
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final settings = ref.read(settingsProvider);
      final useCase = ref.read(exportBackupUseCaseProvider);
      final settingsMap = <String, dynamic>{
        'themeMode': settings.themeMode.index,
        'useDynamicColor': settings.useDynamicColor,
        'useAmoled': settings.useAmoled,
        'gl': settings.gl,
        'hl': settings.hl,
        'crossfadeSeconds': settings.crossfadeSeconds,
        'restoreQueueOnStartup': settings.restoreQueueOnStartup,
        'autoPlayUpNext': settings.autoPlayUpNext,
        'downloadOnlyOnWifi': settings.downloadOnlyOnWifi,
        'trackHistory': settings.trackHistory,
        'checkUpdatesOnStartup': settings.checkUpdatesOnStartup,
      };
      final path = await useCase.execute(settings: settingsMap);

      if (!context.mounted) return;

      if (Platform.isLinux) {
        final dir = await getDownloadsDirectory();
        final destDir = Directory('${dir?.path}/Sonora');
        if (!await destDir.exists()) await destDir.create(recursive: true);
        final file = File(path);
        final destPath = '${destDir.path}/sonora-backup-${DateTime.now().millisecondsSinceEpoch}.zip';
        await file.copy(destPath);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backup saved to $destPath')),
          );
        }
      } else {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(path)], text: 'Sonora backup'),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup exported successfully')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null || result.files.single.path == null) return;
      if (!context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Import backup'),
              content: const Text(
                'This will add backed-up songs, artists, and playlists to your '
                'existing library. No data will be overwritten.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Import'),
                ),
              ],
            ),
      );
      if (confirmed != true) return;

      final useCase = ref.read(importBackupUseCaseProvider);
      final importedSettings = await useCase.execute(result.files.single.path!);

      ref.invalidate(libraryNotifierProvider);

      if (importedSettings != null && context.mounted) {
        final notifier = ref.read(settingsProvider.notifier);
        notifier.setThemeMode(
          ThemeMode.values[importedSettings['themeMode'] as int? ?? 0],
        );
        notifier.setGl(importedSettings['gl'] as String? ?? 'US');
        notifier.setHl(importedSettings['hl'] as String? ?? 'en');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup imported successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }
}

// ── Updates ──────────────────────────────────────────────────────

class _UpdatesSection extends StatelessWidget {
  final Settings settings;
  final SettingsNotifier notifier;

  const _UpdatesSection({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'Updates',
      children: [
        SettingsSwitchTile(
          title: 'Check on startup',
          subtitle: 'Auto-check for updates (max once per 24h)',
          value: settings.checkUpdatesOnStartup,
          onChanged: notifier.setCheckUpdatesOnStartup,
          icon: Icons.update,
        ),
        const Divider(height: 1),
        SettingsButtonTile(
          title: 'Check now',
          icon: Icons.refresh,
          onPressed: () => _checkUpdates(context),
        ),
      ],
    );
  }

  Future<void> _checkUpdates(BuildContext context) async {
    try {
      final uri = Uri.parse(
        'https://api.github.com/repos/$kGitHubRepoOwner/$kGitHubRepoName/releases/latest',
      );
      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final data = jsonDecode(body) as Map<String, dynamic>;
      final latestTag = data['tag_name'] as String? ?? 'unknown';
      final changelog = data['body'] as String? ?? 'No changelog available';
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      if (context.mounted) {
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Update Check'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Current version: $currentVersion'),
                      Text('Latest version: $latestTag'),
                      const SizedBox(height: 16),
                      Text(changelog),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      launchUrl(
                        Uri.parse(kGitHubRepoUrl),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Releases'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update check failed: $e')));
      }
    }
  }
}

// ── About ────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: 'About',
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '...';
            final buildNumber = snapshot.data?.buildNumber ?? '...';
            return ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('App version'),
              subtitle: Text('$version+$buildNumber'),
            );
          },
        ),
        const Divider(height: 1),
        SettingsButtonTile(
          title: 'Licenses',
          icon: Icons.description_outlined,
          onPressed:
              () =>
                  showLicensePage(context: context, applicationName: 'Sonora'),
        ),
        const Divider(height: 1),
        SettingsButtonTile(
          title: 'GitHub repository',
          icon: Icons.code,
          subtitle: kGitHubRepoUrl,
          onPressed:
              () => launchUrl(
                Uri.parse(kGitHubRepoUrl),
                mode: LaunchMode.externalApplication,
              ),
        ),
      ],
    );
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/export_backup_use_case_provider.dart';
import '../../providers/import_backup_use_case_provider.dart';
import '../../providers/library_notifier.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_notifier.dart';
import '../library/providers/library_provider.dart';
import '../search/providers/search_provider.dart';
import '../../shared/widgets/sonora_logo.dart';
import 'settings_shared.dart';
import 'widgets/local_sync_bottom_sheet.dart';

class SettingsScreenContent extends ConsumerWidget {
  const SettingsScreenContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: SettingsCategory.values.length,
      itemBuilder: (context, index) {
        final category = SettingsCategory.values[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Icon(category.icon, color: theme.colorScheme.primary),
            title: Text(
              category.getTitle(context),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              category.getSubtitle(context),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => SettingsCategoryScreen(category: category),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class SettingsCategoryScreen extends StatelessWidget {
  final SettingsCategory category;

  const SettingsCategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.getTitle(context)),
        centerTitle: false,
      ),
      body: SettingsCategoryContent(category: category),
    );
  }
}

class SettingsCategoryContent extends ConsumerWidget {
  final SettingsCategory category;

  const SettingsCategoryContent({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    switch (category) {
      case SettingsCategory.appearance:
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _AppearanceSection(settings: settings, notifier: notifier),
          ],
        );
      case SettingsCategory.playback:
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _PlaybackSection(settings: settings, notifier: notifier),
            _ContentSection(settings: settings, notifier: notifier),
            _ConnectionSection(settings: settings, notifier: notifier),
          ],
        );
      case SettingsCategory.downloads:
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _DownloadSection(settings: settings, notifier: notifier),
            if (isAndroid) const _BatterySection(),
          ],
        );
      case SettingsCategory.privacy:
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _PrivacySection(settings: settings, notifier: notifier, ref: ref),
          ],
        );
      case SettingsCategory.backup:
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [_BackupSection(ref: ref)],
        );
      case SettingsCategory.about:
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _UpdatesSection(settings: settings, notifier: notifier, ref: ref),
            _SupportSection(),
            _AboutSection(),
          ],
        );
    }
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
    final labels = [
      AppLocalizations.of(context)!.system,
      AppLocalizations.of(context)!.light,
      AppLocalizations.of(context)!.dark,
    ];

    return SettingsSection(
      title: AppLocalizations.of(context)!.appearance,
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
            title: AppLocalizations.of(context)!.amoledDarkMode,
            subtitle: AppLocalizations.of(context)!.amoledDarkModeHint,
            value: settings.useAmoled,
            onChanged: notifier.setUseAmoled,
            icon: LucideIcons.moon,
          ),
        SettingsSwitchTile(
          title: AppLocalizations.of(context)!.dynamicColor,
          subtitle: AppLocalizations.of(context)!.dynamicColorHint,
          value: settings.useDynamicColor,
          onChanged: notifier.setUseDynamicColor,
          icon: LucideIcons.palette,
        ),
        SettingsSwitchTile(
          title: AppLocalizations.of(context)!.reduceEffects,
          subtitle: AppLocalizations.of(context)!.reduceEffectsHint,
          value: settings.reduceEffects,
          onChanged: notifier.setReduceEffects,
          icon: LucideIcons.cpu,
        ),
        SettingsSwitchTile(
          title: AppLocalizations.of(context)!.useVinylStyle,
          subtitle: AppLocalizations.of(context)!.useVinylStyleHint,
          value: settings.useVinylStyle,
          onChanged: notifier.setUseVinylStyle,
          icon: LucideIcons.disc,
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
      title: AppLocalizations.of(context)!.content,
      children: [
        SettingsDropdownTile(
          title: AppLocalizations.of(context)!.countryGl,
          value: settings.gl,
          options: kCountryCodes,
          onChanged: (v) {
            if (v != null) notifier.setGl(v);
          },
        ),
        const Divider(height: 1),
        SettingsDropdownTile(
          title: AppLocalizations.of(context)!.languageHl,
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
      title: AppLocalizations.of(context)!.playback,
      children: [
        SettingsSliderTile(
          title: AppLocalizations.of(context)!.crossfade,
          subtitle: AppLocalizations.of(context)!.duration,
          value: settings.crossfadeSeconds.toDouble(),
          min: 0,
          max: 12,
          displayValue: (v) => '${v.round()}s',
          onChanged: (v) => notifier.setCrossfadeSeconds(v.round()),
        ),
        const Divider(height: 1),
        SettingsSwitchTile(
          title: AppLocalizations.of(context)!.restoreQueueOnStartup,
          value: settings.restoreQueueOnStartup,
          onChanged: notifier.setRestoreQueueOnStartup,
          icon: LucideIcons.rotateCcw,
        ),
        const Divider(height: 1),
        SettingsSwitchTile(
          title: AppLocalizations.of(context)!.autoPlayUpNext,
          subtitle: AppLocalizations.of(context)!.autoPlayUpNextHint,
          value: settings.autoPlayUpNext,
          onChanged: notifier.setAutoPlayUpNext,
          icon: LucideIcons.listVideo,
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
      title: AppLocalizations.of(context)!.downloadsSettings,
      children: [
        SettingsButtonTile(
          title: AppLocalizations.of(context)!.downloadFolder,
          subtitle:
              settings.downloadPath ??
              AppLocalizations.of(context)!.defaultLocation,
          icon: LucideIcons.folder,
          onPressed: () async {
            final path = await FilePicker.getDirectoryPath();
            if (path != null) notifier.setDownloadPath(path);
          },
        ),
        const Divider(height: 1),
        SettingsSwitchTile(
          title: AppLocalizations.of(context)!.downloadOnlyOnWifi,
          value: settings.downloadOnlyOnWifi,
          onChanged: notifier.setDownloadOnlyOnWifi,
          icon: LucideIcons.wifi,
        ),
      ],
    );
  }
}

// ── Connection ───────────────────────────────────────────────────

class _ConnectionSection extends StatelessWidget {
  final Settings settings;
  final SettingsNotifier notifier;

  const _ConnectionSection({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsSection(
      title: l10n.connection,
      children: [
        SettingsSwitchTile(
          title: l10n.offlineMode,
          subtitle: l10n.offlineModeHint,
          value: settings.offlineMode,
          onChanged: notifier.setOfflineMode,
          icon: LucideIcons.wifiOff,
        ),
      ],
    );
  }
}

// ── Battery Optimization (Android) ───────────────────────────────

class _BatterySection extends ConsumerWidget {
  const _BatterySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final batteryAsync = ref.watch(batteryOptimizationProvider);
    final manBatteryAsync = ref.watch(manufacturerBatteryOptimizationProvider);

    final batteryDisabled = batteryAsync.value ?? false;
    final manBatteryDisabled = manBatteryAsync.value ?? false;

    return SettingsSection(
      title: l10n.batteryOptimization,
      children: [
        SettingsSwitchTile(
          title: l10n.disableBatteryOptimization,
          subtitle: l10n.disableBatteryOptimizationHint,
          value: batteryDisabled,
          icon: LucideIcons.batteryFull,
          onChanged: (_) async {
            await ref
                .read(settingsProvider.notifier)
                .requestDisableBatteryOptimization();
            ref.invalidate(batteryOptimizationProvider);
          },
        ),
        const Divider(height: 1),
        SettingsSwitchTile(
          title: l10n.manufacturerBatteryOptimization,
          subtitle: l10n.manufacturerBatteryOptimizationHint,
          value: manBatteryDisabled,
          icon: LucideIcons.leaf,
          onChanged: (_) async {
            await ref
                .read(settingsProvider.notifier)
                .requestDisableManufacturerOptimization();
            ref.invalidate(manufacturerBatteryOptimizationProvider);
          },
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
      title: AppLocalizations.of(context)!.privacy,
      children: [
        SettingsSwitchTile(
          title: AppLocalizations.of(context)!.trackListeningHistory,
          value: settings.trackHistory,
          onChanged: notifier.setTrackHistory,
          icon: LucideIcons.history,
        ),
        const Divider(height: 1),
        SettingsButtonTile(
          title: AppLocalizations.of(context)!.clearSearchHistory,
          icon: LucideIcons.searchX,
          onPressed: () => _clearSearchHistory(context),
        ),
        const Divider(height: 1),
        SettingsButtonTile(
          title: AppLocalizations.of(context)!.clearListeningHistory,
          icon: LucideIcons.trash2,
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
            title: Text(AppLocalizations.of(context)!.clearSearchHistory),
            content: Text(
              AppLocalizations.of(context)!.clearSearchHistoryConfirm,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.of(context)!.clear),
              ),
            ],
          ),
    );
    if (confirm == true) {
      await ref.read(libraryNotifierProvider.notifier).clearSearchHistory();
      if (context.mounted) {
        ref.invalidate(recentSearchesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.searchHistoryCleared),
          ),
        );
      }
    }
  }

  Future<void> _clearListeningHistory(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.clearListeningHistory),
            content: Text(
              AppLocalizations.of(context)!.clearSearchHistoryConfirm,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.of(context)!.clear),
              ),
            ],
          ),
    );
    if (confirm == true) {
      await ref.read(libraryNotifierProvider.notifier).clearHistory();
      if (context.mounted) {
        ref.invalidate(libraryHistoryProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.listeningHistoryCleared,
            ),
          ),
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
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);

    return SettingsSection(
      title: l10n.backupRestore,
      children: [
        SettingsButtonTile(
          title: l10n.exportData,
          subtitle: l10n.exportDataHint,
          icon: LucideIcons.fileUp,
          onPressed: () => _exportData(context),
        ),
        const Divider(height: 1),
        SettingsButtonTile(
          title: l10n.importData,
          subtitle: l10n.importDataHint,
          icon: LucideIcons.fileDown,
          onPressed: () => _importData(context),
        ),
        const Divider(height: 1),
        SettingsSwitchTile(
          title: l10n.localSyncEnabled,
          subtitle: l10n.localSyncEnabledHint,
          value: settings.localSyncEnabled,
          icon: LucideIcons.wifi,
          onChanged:
              (value) => ref
                  .read(settingsProvider.notifier)
                  .setLocalSyncEnabled(value),
        ),
        const Divider(height: 1),
        SettingsButtonTile(
          title: l10n.localSync,
          subtitle: l10n.syncNowHint,
          icon: LucideIcons.refreshCw,
          onPressed: () => LocalSyncBottomSheet.show(context),
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
        'isLibraryGridView': settings.isLibraryGridView,
        'useVinylStyle': settings.useVinylStyle,
        'reduceEffects': settings.reduceEffects,
        'offlineMode': settings.offlineMode,
      };
      final path = await useCase.execute(settings: settingsMap);

      if (!context.mounted) return;

      if (Platform.isLinux) {
        final dir = await getDownloadsDirectory();
        final destDir = Directory('${dir?.path}/Sonora');
        if (!await destDir.exists()) await destDir.create(recursive: true);
        final file = File(path);
        final destPath =
            '${destDir.path}/sonora-backup-${DateTime.now().millisecondsSinceEpoch}.zip';
        await file.copy(destPath);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.backupSaved(destPath),
              ),
            ),
          );
        }
      } else {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(path)],
            text: AppLocalizations.of(context)!.appTitle,
          ),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.backupExportedSuccessfully,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.exportFailed(e.toString()),
            ),
          ),
        );
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
              title: Text(AppLocalizations.of(context)!.importBackup),
              content: Text(AppLocalizations.of(context)!.importBackupConfirm),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(AppLocalizations.of(context)!.import),
                ),
              ],
            ),
      );
      if (confirmed != true) return;

      final useCase = ref.read(importBackupUseCaseProvider);
      final importedSettings = await useCase.execute(result.files.single.path!);

      ref.invalidate(libraryNotifierProvider);
      ref.invalidate(likedSongsProvider);
      ref.invalidate(followedArtistsProvider);
      ref.invalidate(likedAlbumsProvider);
      ref.invalidate(likedPlaylistsProvider);
      ref.invalidate(playlistsProvider);
      ref.invalidate(libraryHistoryProvider);

      if (importedSettings != null && context.mounted) {
        final notifier = ref.read(settingsProvider.notifier);
        if (importedSettings.containsKey('themeMode')) {
          notifier.setThemeMode(
            ThemeMode.values[importedSettings['themeMode'] as int],
          );
        }
        if (importedSettings.containsKey('useDynamicColor')) {
          notifier.setUseDynamicColor(
            importedSettings['useDynamicColor'] as bool,
          );
        }
        if (importedSettings.containsKey('useAmoled')) {
          notifier.setUseAmoled(importedSettings['useAmoled'] as bool);
        }
        if (importedSettings.containsKey('gl')) {
          notifier.setGl(importedSettings['gl'] as String);
        }
        if (importedSettings.containsKey('hl')) {
          notifier.setHl(importedSettings['hl'] as String);
        }
        if (importedSettings.containsKey('crossfadeSeconds')) {
          notifier.setCrossfadeSeconds(
            importedSettings['crossfadeSeconds'] as int,
          );
        }
        if (importedSettings.containsKey('restoreQueueOnStartup')) {
          notifier.setRestoreQueueOnStartup(
            importedSettings['restoreQueueOnStartup'] as bool,
          );
        }
        if (importedSettings.containsKey('autoPlayUpNext')) {
          notifier.setAutoPlayUpNext(
            importedSettings['autoPlayUpNext'] as bool,
          );
        }
        if (importedSettings.containsKey('downloadOnlyOnWifi')) {
          notifier.setDownloadOnlyOnWifi(
            importedSettings['downloadOnlyOnWifi'] as bool,
          );
        }
        if (importedSettings.containsKey('trackHistory')) {
          notifier.setTrackHistory(importedSettings['trackHistory'] as bool);
        }
        if (importedSettings.containsKey('checkUpdatesOnStartup')) {
          notifier.setCheckUpdatesOnStartup(
            importedSettings['checkUpdatesOnStartup'] as bool,
          );
        }
        if (importedSettings.containsKey('isLibraryGridView')) {
          notifier.setLibraryGridView(
            importedSettings['isLibraryGridView'] as bool,
          );
        }
        if (importedSettings.containsKey('useVinylStyle')) {
          notifier.setUseVinylStyle(importedSettings['useVinylStyle'] as bool);
        }
        if (importedSettings.containsKey('reduceEffects')) {
          notifier.setReduceEffects(importedSettings['reduceEffects'] as bool);
        }
        if (importedSettings.containsKey('offlineMode')) {
          notifier.setOfflineMode(importedSettings['offlineMode'] as bool);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.backupImportedSuccessfully,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.importFailed(e.toString()),
            ),
          ),
        );
      }
    }
  }
}

// ── Updates ──────────────────────────────────────────────────────

class _UpdatesSection extends ConsumerWidget {
  final Settings settings;
  final SettingsNotifier notifier;

  const _UpdatesSection({
    required this.settings,
    required this.notifier,
    required this.ref,
  });

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSection(
      title: AppLocalizations.of(context)!.updates,
      children: [
        SettingsSwitchTile(
          title: AppLocalizations.of(context)!.checkOnStartup,
          subtitle: AppLocalizations.of(context)!.checkOnStartupHint,
          value: settings.checkUpdatesOnStartup,
          onChanged: notifier.setCheckUpdatesOnStartup,
          icon: LucideIcons.refreshCw,
        ),
        const Divider(height: 1),
        SettingsButtonTile(
          title: AppLocalizations.of(context)!.checkNow,
          icon: LucideIcons.refreshCw,
          onPressed: () => _checkUpdates(context, ref),
        ),
      ],
    );
  }

  void _checkUpdates(BuildContext context, WidgetRef ref) {
    ref.read(updateProvider.notifier).reset();
    ref.read(updateProvider.notifier).checkForUpdate();
    _showUpdateDialog(context);
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UpdateDialog(),
    );
  }
}

class _UpdateDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<_UpdateDialog> {
  String _localVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _localVersion = 'v${info.version}+${info.buildNumber}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateProvider);
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(updateProvider.notifier);

    return PopScope(
      canPop:
          state.status != UpdateStatus.checking &&
          state.status != UpdateStatus.downloading,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) notifier.reset();
      },
      child: AlertDialog(
        title: _buildTitle(state, l10n),
        content: _buildContent(state, l10n),
        actions: _buildActions(state, l10n, notifier, context),
      ),
    );
  }

  Widget _buildTitle(UpdateState state, AppLocalizations l10n) {
    switch (state.status) {
      case UpdateStatus.checking:
        return Text(l10n.checkingForUpdates);
      case UpdateStatus.downloading:
        return Text(l10n.downloadingUpdate);
      case UpdateStatus.downloadComplete:
        return Text(l10n.updateAvailable);
      case UpdateStatus.updateAvailable:
        return Text(l10n.updateAvailable);
      case UpdateStatus.noUpdateAvailable:
        return Text(l10n.upToDate);
      case UpdateStatus.error:
        return Text(l10n.error);
      case UpdateStatus.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildContent(UpdateState state, AppLocalizations l10n) {
    switch (state.status) {
      case UpdateStatus.checking:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );

      case UpdateStatus.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: state.progress),
            const SizedBox(height: 12),
            Text('${(state.progress * 100).toStringAsFixed(0)}%'),
          ],
        );

      case UpdateStatus.downloadComplete:
        return Text(l10n.downloadComplete);

      case UpdateStatus.updateAvailable:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_localVersion.isNotEmpty)
                Text(l10n.currentVersion(_localVersion)),
              Text(l10n.latestVersion(state.result?.latestVersion ?? '')),
              if (state.result?.changelog.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text(
                  state.result!.changelog,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        );

      case UpdateStatus.noUpdateAvailable:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_localVersion.isNotEmpty)
              Text(l10n.currentVersion(_localVersion)),
          ],
        );

      case UpdateStatus.error:
        return Text(state.errorMessage ?? l10n.unknownError);

      case UpdateStatus.idle:
        return const SizedBox.shrink();
    }
  }

  List<Widget> _buildActions(
    UpdateState state,
    AppLocalizations l10n,
    UpdateNotifier notifier,
    BuildContext context,
  ) {
    switch (state.status) {
      case UpdateStatus.checking:
      case UpdateStatus.downloading:
        return [];

      case UpdateStatus.downloadComplete:
        return [
          TextButton(
            onPressed: () {
              notifier.reset();
              Navigator.pop(context);
            },
            child: Text(l10n.close),
          ),
          FilledButton.icon(
            onPressed: () => notifier.installApk(),
            icon: const Icon(LucideIcons.smartphone),
            label: Text(l10n.installUpdate),
          ),
        ];

      case UpdateStatus.updateAvailable:
        return [
          TextButton(
            onPressed: () {
              notifier.reset();
              Navigator.pop(context);
            },
            child: Text(l10n.close),
          ),
          if (isAndroid)
            FilledButton.icon(
              onPressed: () => notifier.downloadAndInstall(),
              icon: const Icon(LucideIcons.download),
              label: Text(l10n.downloadUpdate),
            )
          else
            FilledButton.icon(
              onPressed: () {
                notifier.reset();
                Navigator.pop(context);
                launchUrl(
                  Uri.parse('$kGitHubRepoUrl/releases/latest'),
                  mode: LaunchMode.externalApplication,
                );
              },
              icon: const Icon(LucideIcons.externalLink),
              label: Text(l10n.downloadUpdate),
            ),
        ];

      case UpdateStatus.noUpdateAvailable:
        return [
          FilledButton(
            onPressed: () {
              notifier.reset();
              Navigator.pop(context);
            },
            child: Text(l10n.close),
          ),
        ];

      case UpdateStatus.error:
        return [
          TextButton(
            onPressed: () {
              notifier.reset();
              Navigator.pop(context);
            },
            child: Text(l10n.close),
          ),
          if (state.result?.isNewer == true)
            FilledButton.icon(
              onPressed: () => notifier.downloadAndInstall(),
              icon: const Icon(LucideIcons.refreshCw),
              label: Text(l10n.retry),
            ),
        ];

      case UpdateStatus.idle:
        return [];
    }
  }
}

// ── Support ──────────────────────────────────────────────────────

class _SupportSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: AppLocalizations.of(context)!.support,
      children: [
        SettingsButtonTile(
          title: AppLocalizations.of(context)!.donate,
          subtitle: AppLocalizations.of(context)!.donateHint,
          icon: LucideIcons.gift,
          onPressed:
              () => launchUrl(
                Uri.parse(kPaypalDonateUrl),
                mode: LaunchMode.externalApplication,
              ),
        ),
      ],
    );
  }
}

// ── About ────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SettingsSection(
      title: AppLocalizations.of(context)!.about,
      children: [
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '...';
            final buildNumber = snapshot.data?.buildNumber ?? '...';
            return ListTile(
              leading: const SonoraLogo.icon(24),
              title: Text(AppLocalizations.of(context)!.appVersion),
              subtitle: Text('$version+$buildNumber'),
            );
          },
        ),
        const Divider(height: 1),
        SettingsButtonTile(
          title: AppLocalizations.of(context)!.licenses,
          icon: LucideIcons.fileText,
          onPressed:
              () => showLicensePage(
                context: context,
                applicationName: AppLocalizations.of(context)!.appTitle,
              ),
        ),
        const Divider(height: 1),
        SettingsButtonTile(
          title: AppLocalizations.of(context)!.gitHubRepository,
          icon: LucideIcons.code2,
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

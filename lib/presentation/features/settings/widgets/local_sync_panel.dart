import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../data/services/sync_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/sync_provider.dart';
import '../../../../core/constants/app_constants.dart';

class LocalSyncPanel extends ConsumerStatefulWidget {
  final bool isDialog;
  const LocalSyncPanel({super.key, this.isDialog = false});

  static Future<void> show(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= kExpandedBreakpoint;

    if (isWide) {
      return showDialog(
        context: context,
        builder:
            (context) => const Dialog(child: LocalSyncPanel(isDialog: true)),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const LocalSyncPanel(isDialog: false),
      );
    }
  }

  @override
  ConsumerState<LocalSyncPanel> createState() => _LocalSyncPanelState();
}

class _LocalSyncPanelState extends ConsumerState<LocalSyncPanel> {
  late final TextEditingController _pinController;

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(syncNotifierProvider.notifier).resetStatus();
        ref.read(syncNotifierProvider.notifier).startDiscovery();
      }
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncNotifierProvider);
    final syncService = ref.watch(syncServiceProvider);
    final pairedDevices = syncService.getPairedDevicesMetadata();
    final otherDevices =
        syncState.discoveredDevices
            .where((d) => !pairedDevices.any((p) => p.deviceId == d.deviceId))
            .toList();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    double progressValue = 0.1;
    String stageText = l10n.syncingData;
    if (syncState.currentStage == 'exporting') {
      progressValue = 0.15;
      stageText = l10n.syncStageExporting;
    } else if (syncState.currentStage == 'exchanging') {
      progressValue = 0.45;
      stageText = l10n.syncStageExchanging;
    } else if (syncState.currentStage == 'merging') {
      progressValue = 0.75;
      stageText = l10n.syncStageMerging;
    } else if (syncState.currentStage == 'finalizing') {
      progressValue = 0.95;
      stageText = l10n.syncStageFinalizing;
    }

    // Map raw error messages to user-friendly localizations
    String? friendlyError;
    if (syncState.errorMessage == 'incorrectPin') {
      friendlyError = l10n.incorrectPinError;
    } else if (syncState.errorMessage == 'pairingRemoved') {
      friendlyError = l10n.pairingRemovedError;
    } else if (syncState.rawErrorMessage != null) {
      final err = syncState.rawErrorMessage!.toLowerCase();
      if (err.contains('socketexception') || err.contains('host unreachable')) {
        friendlyError = l10n.weakConnectionError;
      } else if (err.contains('permission denied')) {
        friendlyError = l10n.failedToPlay(
          'Network permission denied. Please check app permissions.',
        );
      }
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                l10n.localSync,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (syncState.status == SyncStatus.scanning) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Column(
                children: [CircularProgressIndicator(), SizedBox(height: 16)],
              ),
            ),
          ),
          Center(
            child: Text(
              l10n.searchingDevices,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ] else if (syncState.status == SyncStatus.syncing) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 16),
                Text(
                  stageText,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progressValue * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ] else if (syncState.status == SyncStatus.waitingForPin) ...[
          _buildPinInputSection(theme, l10n),
        ] else if (syncState.status == SyncStatus.success) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Icon(
                LucideIcons.checkCircle,
                color: Colors.green,
                size: 56,
              ),
            ),
          ),
          Center(
            child: Text(
              l10n.syncSummarySuccess,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSyncStatsSummary(theme, l10n, syncState.syncStats),
          const SizedBox(height: 24),
          FilledButton(
            onPressed:
                () =>
                    ref.read(syncNotifierProvider.notifier).resetSuccessState(),
            child: Text(l10n.close),
          ),
        ] else if (syncState.status == SyncStatus.error) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Icon(
                LucideIcons.alertTriangle,
                color: Colors.red,
                size: 64,
              ),
            ),
          ),
          Center(
            child: Text(
              friendlyError ?? l10n.unknownError,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (kDebugMode && syncState.rawErrorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                syncState.rawErrorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.close),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed:
                      () =>
                          ref
                              .read(syncNotifierProvider.notifier)
                              .startDiscovery(),
                  child: Text(l10n.checkNow),
                ),
              ),
            ],
          ),
        ] else ...[
          if (syncState.discoveredDevices.isEmpty && pairedDevices.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Column(
                children: [
                  const Icon(LucideIcons.wifiOff, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noDevicesFound,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              icon: const Icon(LucideIcons.refreshCw),
              label: Text(l10n.checkNow),
              onPressed:
                  () =>
                      ref.read(syncNotifierProvider.notifier).startDiscovery(),
            ),
          ] else ...[
            if (pairedDevices.isNotEmpty) ...[
              Text(
                l10n.pairedDevicesSection,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: pairedDevices.length,
                  itemBuilder: (context, index) {
                    final paired = pairedDevices[index];
                    DiscoveredSyncDevice? discovered;
                    try {
                      discovered = syncState.discoveredDevices.firstWhere(
                        (d) => d.deviceId == paired.deviceId,
                      );
                    } catch (_) {
                      discovered = null;
                    }

                    final isOnline = discovered != null;
                    final device =
                        discovered ??
                        DiscoveredSyncDevice(
                          ip: paired.ip,
                          port: paired.port,
                          name: paired.name,
                          deviceId: paired.deviceId,
                        );

                    return _buildDeviceCard(
                      device: device,
                      theme: theme,
                      isPaired: true,
                      isOnline: isOnline,
                      l10n: l10n,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (otherDevices.isNotEmpty) ...[
              Text(
                l10n.otherDevicesSection,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: otherDevices.length,
                  itemBuilder: (context, index) {
                    final device = otherDevices[index];
                    return _buildDeviceCard(
                      device: device,
                      theme: theme,
                      isPaired: false,
                      isOnline: false,
                      l10n: l10n,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            OutlinedButton.icon(
              icon: const Icon(LucideIcons.refreshCw),
              label: Text(l10n.checkNow),
              onPressed:
                  () =>
                      ref.read(syncNotifierProvider.notifier).startDiscovery(),
            ),
          ],
          _buildResetPairingsButton(theme, l10n),
        ],
      ],
    );

    if (widget.isDialog) {
      return Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(child: content),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(top: false, child: SingleChildScrollView(child: content)),
    );
  }

  Widget _buildPinInputSection(ThemeData theme, AppLocalizations l10n) {
    final titleText = l10n.pairingRequiredTitle;
    final descText = l10n.pairingRequiredDesc;
    final confirmText = l10n.confirm;
    final cancelText = l10n.cancel;

    return Column(
      children: [
        const SizedBox(height: 12),
        Icon(LucideIcons.key, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          titleText,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          descText,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 150,
          child: TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              counterText: '',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            autofocus: true,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton(
              onPressed: () {
                _pinController.clear();
                ref.read(syncNotifierProvider.notifier).cancelPinInput();
              },
              child: Text(cancelText),
            ),
            FilledButton(
              onPressed: () {
                final pin = _pinController.text.trim();
                if (pin.length == 4) {
                  _pinController.clear();
                  ref.read(syncNotifierProvider.notifier).submitPin(pin);
                }
              },
              child: Text(confirmText),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildResetPairingsButton(ThemeData theme, AppLocalizations l10n) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(LucideIcons.trash2, size: 16),
          label: Text(l10n.resetPairedDevices),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: Text(l10n.resetPairedDevicesConfirmTitle),
                    content: Text(l10n.resetPairedDevicesConfirmMsg),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(l10n.confirm),
                      ),
                    ],
                  ),
            );
            if (confirm != true) return;

            await ref.read(syncNotifierProvider.notifier).clearPairedDevices();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.resetPairedDevicesSuccess)),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildDeviceCard({
    required DiscoveredSyncDevice device,
    required ThemeData theme,
    required bool isPaired,
    required bool isOnline,
    required AppLocalizations l10n,
  }) {
    final leadingColor =
        isPaired
            ? (isOnline ? Colors.green : Colors.grey)
            : theme.colorScheme.primary;

    final isSmartphone =
        device.name.toLowerCase().contains('android') ||
        device.name.toLowerCase().contains('phone') ||
        device.name.toLowerCase().contains('pixel');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(
          isSmartphone ? LucideIcons.smartphone : LucideIcons.monitor,
          color: leadingColor,
        ),
        title:
            isPaired
                ? Row(
                  children: [
                    Expanded(child: Text(device.name)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isOnline
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color:
                              isOnline
                                  ? Colors.green.withValues(alpha: 0.5)
                                  : Colors.grey.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        isOnline ? l10n.online : l10n.offline,
                        style: TextStyle(
                          color: isOnline ? Colors.green : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                )
                : Text(device.name),
        subtitle: Text('${device.ip}:${device.port}'),
        trailing: const Icon(LucideIcons.refreshCw, size: 18),
        onTap: () => ref.read(syncNotifierProvider.notifier).syncWith(device),
      ),
    );
  }

  Widget _buildSyncStatsSummary(
    ThemeData theme,
    AppLocalizations l10n,
    Map<String, int>? stats,
  ) {
    if (stats == null || stats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            l10n.syncSummaryNoChanges,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    final likedSongs = stats['likedSongs'] ?? 0;
    final followedArtists = stats['followedArtists'] ?? 0;
    final likedAlbums = stats['likedAlbums'] ?? 0;
    final likedPlaylists = stats['likedPlaylists'] ?? 0;
    final playlists = stats['playlists'] ?? 0;
    final playlistEntries = stats['playlistEntries'] ?? 0;
    final history = stats['history'] ?? 0;

    final totalChanges =
        likedSongs +
        followedArtists +
        likedAlbums +
        likedPlaylists +
        playlists +
        playlistEntries +
        history;

    if (totalChanges == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            l10n.syncSummaryNoChanges,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
        ),
      );
    }

    final List<Widget> statRows = [];

    void addStatRow(IconData icon, String text) {
      statRows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            ],
          ),
        ),
      );
    }

    if (likedSongs > 0) {
      addStatRow(LucideIcons.heart, l10n.syncSummaryAddedSongs(likedSongs));
    }
    if (playlists > 0) {
      addStatRow(
        LucideIcons.listMusic,
        l10n.syncSummaryAddedPlaylists(playlists),
      );
    }
    if (followedArtists > 0) {
      addStatRow(
        LucideIcons.users,
        l10n.syncSummaryAddedArtists(followedArtists),
      );
    }
    if (likedAlbums > 0) {
      addStatRow(LucideIcons.disc, l10n.syncSummaryAddedAlbums(likedAlbums));
    }
    if (history > 0) {
      addStatRow(LucideIcons.history, l10n.syncSummaryAddedHistory(history));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.syncSummaryTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...statRows,
        ],
      ),
    );
  }
}

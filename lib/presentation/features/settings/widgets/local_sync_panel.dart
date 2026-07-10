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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(syncNotifierProvider.notifier).resetStatus();
        ref.read(syncNotifierProvider.notifier).startDiscovery();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncNotifierProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Map raw error messages to user-friendly localizations
    String? friendlyError;
    if (syncState.rawErrorMessage != null) {
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
              l10n.syncingData,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ] else if (syncState.status == SyncStatus.success) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Icon(
                LucideIcons.checkCircle,
                color: Colors.green,
                size: 64,
              ),
            ),
          ),
          Center(
            child: Text(
              l10n.syncSuccess,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
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
          if (syncState.discoveredDevices.isEmpty) ...[
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
            Text(
              l10n.devicesFound,
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
                itemCount: syncState.discoveredDevices.length,
                itemBuilder: (context, index) {
                  final DiscoveredSyncDevice device =
                      syncState.discoveredDevices[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: Icon(
                        device.name.toLowerCase().contains('android') ||
                                device.name.toLowerCase().contains('phone') ||
                                device.name.toLowerCase().contains('pixel')
                            ? LucideIcons.smartphone
                            : LucideIcons.monitor,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(device.name),
                      subtitle: Text('${device.ip}:${device.port}'),
                      trailing: const Icon(LucideIcons.refreshCw, size: 18),
                      onTap:
                          () => ref
                              .read(syncNotifierProvider.notifier)
                              .syncWith(device),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(LucideIcons.refreshCw),
              label: Text(l10n.checkNow),
              onPressed:
                  () =>
                      ref.read(syncNotifierProvider.notifier).startDiscovery(),
            ),
          ],
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
}

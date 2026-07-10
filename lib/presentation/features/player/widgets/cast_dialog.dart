import 'package:dart_cast/dart_cast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/cast_provider.dart';
import '../../../../core/constants/app_constants.dart';

class CastDialog extends ConsumerStatefulWidget {
  final bool isDialog;
  const CastDialog({super.key, this.isDialog = false});

  static Future<void> show(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= kExpandedBreakpoint;

    if (isWide) {
      return showDialog(
        context: context,
        builder:
            (context) => const Dialog(
              child: SizedBox(width: 450, child: CastDialog(isDialog: true)),
            ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => const CastDialog(isDialog: false),
      );
    }
  }

  @override
  ConsumerState<CastDialog> createState() => _CastDialogState();
}

class _CastDialogState extends ConsumerState<CastDialog> {
  late final CastNotifier _castNotifier;

  @override
  void initState() {
    super.initState();
    _castNotifier = ref.read(castStateProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _castNotifier.startDiscovery();
    });
  }

  @override
  void dispose() {
    Future.microtask(() {
      _castNotifier.stopDiscovery();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final castStateAsync = ref.watch(castStateProvider);

    return castStateAsync.when(
      data: (state) => _buildContent(context, state, l10n),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }

  Widget _buildContent(
    BuildContext context,
    CastState state,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.castToDevice,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.isDiscovering)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (widget.isDialog) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (state.discoveredDevices.isEmpty && !state.isDiscovering)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(l10n.noResults),
                    ),
                  ...state.discoveredDevices.map((device) {
                    final isConnected =
                        state.activeDevice?.id == device.id &&
                        state.connectionState == CastConnectionState.connected;
                    final isConnecting =
                        state.activeDevice?.id == device.id &&
                        state.connectionState == CastConnectionState.connecting;

                    return ListTile(
                      leading: Icon(
                        device.protocol == CastProtocol.chromecast
                            ? LucideIcons.cast
                            : LucideIcons.monitor,
                      ),
                      title: Text(device.name),
                      subtitle: Text(
                        device.protocol
                            .toString()
                            .split('.')
                            .last
                            .toUpperCase(),
                      ),
                      trailing:
                          isConnecting
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : isConnected
                              ? Icon(
                                LucideIcons.check,
                                color: theme.colorScheme.primary,
                              )
                              : null,
                      onTap:
                          isConnected
                              ? () =>
                                  ref
                                      .read(castStateProvider.notifier)
                                      .disconnect()
                              : () => ref
                                  .read(castStateProvider.notifier)
                                  .connect(device),
                    );
                  }),
                  const Divider(),
                  ListTile(
                    leading: const Icon(LucideIcons.bluetooth),
                    title: Text(l10n.alexaBluetooth),
                    subtitle: Text(l10n.alexaBluetoothInstructions),
                    onTap: () {
                      ref
                          .read(castStateProvider.notifier)
                          .openBluetoothSettings();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(LucideIcons.settings),
                        label: Text(l10n.openBluetoothSettings),
                        onPressed:
                            () =>
                                ref
                                    .read(castStateProvider.notifier)
                                    .openBluetoothSettings(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (state.activeDevice != null &&
              state.connectionState == CastConnectionState.connected)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      () => ref.read(castStateProvider.notifier).disconnect(),
                  child: Text(l10n.disconnect),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

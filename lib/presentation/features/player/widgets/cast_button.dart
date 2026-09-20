import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/cast_provider.dart';
import '../../../providers/connectivity_provider.dart';
import 'cast_dialog.dart';

class CastButton extends ConsumerWidget {
  final Color? color;
  final double? size;
  final ButtonStyle? style;

  const CastButton({super.key, this.color, this.size, this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castStateAsync = ref.watch(castStateProvider);
    final isOffline = ref.watch(isOfflineProvider);

    return castStateAsync.maybeWhen(
      data: (state) {
        final isConnected =
            state.connectionState == CastConnectionState.connected;
        final theme = Theme.of(context);
        final l10n = AppLocalizations.of(context);
        final deviceName = state.activeDevice?.name;
        final iconSize = size ?? 24.0;
        final tooltip =
            isOffline
                ? (l10n?.noConnectionMessage)
                : (isConnected && deviceName != null && l10n != null
                    ? l10n.castConnectedTo(deviceName)
                    : null);

        return IconButton(
          style: style,
          tooltip: tooltip,
          icon:
              isConnected
                  ? Badge(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.all(2),
                    label: Icon(
                      LucideIcons.check,
                      size: 10,
                      color: theme.colorScheme.onPrimary,
                    ),
                    child: Icon(
                      LucideIcons.cast,
                      color: theme.colorScheme.primary,
                      size: iconSize,
                    ),
                  )
                  : Icon(LucideIcons.cast, color: color, size: iconSize),
          onPressed:
              isOffline
                  ? null
                  : () {
                    CastDialog.show(context);
                  },
        );
      },
      orElse:
          () => IconButton(
            style: style,
            icon: Icon(LucideIcons.cast, color: color, size: size),
            onPressed: null,
          ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/battery_prompt_provider.dart';
import '../../providers/settings_provider.dart';

/// Adaptive dialog / bottom sheet inviting the user to disable Android battery
/// optimization for uninterrupted background playback.
Future<void> showBatteryOptimizationPrompt(
  BuildContext context,
  WidgetRef ref,
) {
  final width = MediaQuery.of(context).size.width;
  final isWide = width >= kExpandedBreakpoint;

  Widget buildContent(BuildContext routeCtx) {
    final l10n = AppLocalizations.of(routeCtx)!;
    final colorScheme = Theme.of(routeCtx).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWide)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.pop(routeCtx),
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                ),
              ),
            ),
          Icon(LucideIcons.batteryFull, size: 40, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            l10n.backgroundPlaybackPromptTitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              routeCtx,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.backgroundPlaybackPromptMessage,
            textAlign: TextAlign.center,
            style: Theme.of(routeCtx).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                Navigator.pop(routeCtx);
                await ref
                    .read(settingsProvider.notifier)
                    .requestDisableBatteryOptimization();
                ref.invalidate(batteryOptimizationProvider);
                ref.invalidate(shouldShowBatteryPromptProvider);
              },
              child: Text(l10n.disableNow),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(routeCtx),
              child: Text(l10n.notNow),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () async {
              await ref
                  .read(settingsProvider.notifier)
                  .dismissBatteryPromptForever();
              if (routeCtx.mounted) Navigator.pop(routeCtx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.batteryPromptDismissedHint),
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            },
            child: Text(
              l10n.dontShowAgain,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  if (isWide) {
    return showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            child: Container(
              width: 400,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(child: buildContent(ctx)),
            ),
          ),
    );
  }

  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(child: SingleChildScrollView(child: buildContent(ctx)));
    },
  );
}

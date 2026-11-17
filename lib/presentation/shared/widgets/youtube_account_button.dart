import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/settings/device_link_qr_panel.dart';
import '../../features/settings/device_link_scanner_screen.dart';
import '../../features/settings/youtube_login_webview.dart';
import '../../features/tv/widgets/tv_youtube_account_dialog.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/android_tv_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/youtube_account_provider.dart';

/// Shared display label for YouTube Music account controls across shells.
String resolveYoutubeAccountLabel(
  BuildContext context,
  WidgetRef ref, {
  bool signInPromptWhenGuest = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  final signedIn = ref.watch(youtubeAccountProvider).signedIn;
  if (!signedIn) {
    return signInPromptWhenGuest ? l10n.accountSignIn : l10n.account;
  }
  final info = ref.watch(youtubeAccountInfoProvider).asData?.value;
  return info?.name ?? l10n.accountSignedIn;
}

/// Circular YouTube Music avatar when signed in, or user icon when guest.
class YoutubeAccountAvatar extends ConsumerWidget {
  const YoutubeAccountAvatar({super.key, this.size = 24, this.iconColor});

  final double size;
  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(youtubeAccountProvider).signedIn;
    if (!signedIn) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Icon(
            LucideIcons.user,
            size: math.min(size, 26),
            color: iconColor,
          ),
        ),
      );
    }

    final photoUrl = ref
        .watch(youtubeAccountInfoProvider)
        .asData
        ?.value
        ?.photoUrl;
    final colorScheme = Theme.of(context).colorScheme;

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.primary, width: 1.5),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, _) => _FallbackSignedInIcon(size: size),
            errorWidget: (_, _, _) => _FallbackSignedInIcon(size: size),
          ),
        ),
      );
    }

    return _FallbackSignedInIcon(size: size);
  }
}

class _FallbackSignedInIcon extends StatelessWidget {
  const _FallbackSignedInIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary.withValues(alpha: 0.16),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.6)),
      ),
      alignment: Alignment.center,
      child: Icon(
        LucideIcons.userCheck,
        size: size * 0.6,
        color: colorScheme.primary,
      ),
    );
  }
}

/// Mobile AppBar action for YouTube Music account status and details.
class YoutubeAccountIconButton extends ConsumerWidget {
  const YoutubeAccountIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tooltip = resolveYoutubeAccountLabel(
      context,
      ref,
      signInPromptWhenGuest: true,
    );

    return IconButton(
      key: const Key('youtube-account-appbar-button'),
      tooltip: tooltip,
      onPressed: () => unawaited(handleYoutubeAccountTap(context, ref)),
      icon: const YoutubeAccountAvatar(size: 26),
    );
  }
}

/// Compact 48px rail button used in [TabletShell] and collapsed [WideShell].
class YoutubeAccountRailButton extends ConsumerWidget {
  const YoutubeAccountRailButton({super.key, this.buttonKey});

  final Key? buttonKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = resolveYoutubeAccountLabel(context, ref);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Tooltip(
        message: label,
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: TextButton(
            key: buttonKey,
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              padding: EdgeInsets.zero,
            ),
            onPressed: () => unawaited(handleYoutubeAccountTap(context, ref)),
            child: const YoutubeAccountAvatar(size: 24),
          ),
        ),
      ),
    );
  }
}

/// Runs platform sign-in when guest, or opens the account details panel.
Future<void> handleYoutubeAccountTap(
  BuildContext context,
  WidgetRef ref,
) async {
  final signedIn = ref.read(youtubeAccountProvider).signedIn;
  if (signedIn) {
    await YoutubeAccountSheet.show(context);
    return;
  }

  final l10n = AppLocalizations.of(context)!;
  if (ref.read(isOfflineProvider)) {
    ref.read(actionFeedbackProvider.notifier).report(l10n.offlineNotification);
    return;
  }

  final isTv = ref.read(isAndroidTvProvider);
  if (isTv || isLinux) {
    await DeviceLinkQrPanel.showAsDialog(context);
    return;
  }

  if (isAndroid) {
    final ok = await YoutubeLoginWebView.open(context);
    if (ok == true && context.mounted) {
      ref.read(actionFeedbackProvider.notifier).report(l10n.accountSignedIn);
    }
    return;
  }

  ref
      .read(actionFeedbackProvider.notifier)
      .report(l10n.accountSignInUnavailable);
}

/// Prompts for sign-out confirmation and signs out when confirmed.
Future<bool> confirmYoutubeSignOut(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context)!;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.accountSignOut),
      content: Text(l10n.accountSignOutConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.accountSignOut),
        ),
      ],
    ),
  );
  if (confirm != true) return false;
  await ref.read(youtubeAccountProvider.notifier).signOut();
  return true;
}

/// Account details overlay: bottom sheet below 1200px, dialog on wide / TV.
class YoutubeAccountSheet extends ConsumerWidget {
  const YoutubeAccountSheet({super.key, required this.isDialog});

  final bool isDialog;

  static Future<void> show(BuildContext context) {
    final isTv = ProviderScope.containerOf(context).read(isAndroidTvProvider);
    if (isTv) {
      return showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        builder: (_) => const TvYoutubeAccountDialog(),
      );
    }

    if (MediaQuery.sizeOf(context).width >= kExpandedBreakpoint) {
      return showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: const YoutubeAccountSheet(isDialog: true),
          ),
        ),
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const YoutubeAccountSheet(isDialog: false),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOffline = ref.watch(isOfflineProvider);
    final info = ref.watch(youtubeAccountInfoProvider).asData?.value;
    final displayName = info?.name ?? l10n.accountSignedIn;
    final handle = info?.channelHandle;
    final email = info?.email;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, isDialog ? 16 : 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isDialog) ...[
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.account,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.x),
                tooltip: l10n.close,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const YoutubeAccountAvatar(size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (handle != null && handle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (email != null && email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.check,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.accountSignedIn,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isAndroid)
            ListTile(
              enabled: !isOffline,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(
                LucideIcons.scanQrCode,
                color: isOffline
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.primary,
              ),
              title: Text(l10n.accountLinkDevice),
              subtitle: Text(l10n.accountLinkDeviceHint),
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                DeviceLinkScannerScreen.open(navigator.context);
              },
            ),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Icon(LucideIcons.logOut, color: colorScheme.error),
            title: Text(
              l10n.accountSignOut,
              style: TextStyle(color: colorScheme.error),
            ),
            onTap: () async {
              if (await confirmYoutubeSignOut(context, ref) &&
                  context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }
}

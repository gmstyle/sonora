import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/youtube_account_provider.dart';
import '../../../shared/widgets/youtube_account_button.dart';
import '../tv_metrics.dart';
import 'tv_focusable.dart';

/// 10-foot Android TV dialog showing the connected YouTube Music account.
class TvYoutubeAccountDialog extends ConsumerWidget {
  const TvYoutubeAccountDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final info = ref.watch(youtubeAccountInfoProvider).asData?.value;
    final displayName = info?.name ?? l10n.accountSignedIn;
    final handle = info?.channelHandle;
    final email = info?.email;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: TvColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: TvColors.border),
          ),
          elevation: 16,
          clipBehavior: Clip.antiAlias,
          child: FocusScope(
            autofocus: true,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.account,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: TvColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: TvColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: TvColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const YoutubeAccountAvatar(size: 56),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: TvColors.textPrimary,
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
                                    color: TvColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TvFocusable(
                          onSelect: () async {
                            await ref
                                .read(youtubeAccountProvider.notifier)
                                .signOut();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: colorScheme.error.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.error.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.logOut,
                                  size: 18,
                                  color: colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.accountSignOut,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TvFocusable(
                          autofocus: true,
                          onSelect: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: TvColors.surfaceButton,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: TvColors.borderSubtle),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              l10n.close,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: TvColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

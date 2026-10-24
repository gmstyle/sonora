import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/settings/settings_shared.dart';
import '../../providers/ask_intro_provider.dart';
import '../../providers/settings_provider.dart';

/// Adaptive paged sheet / dialog announcing Ask on first launch after upgrade.
Future<void> showAskIntroWizard(BuildContext context, WidgetRef ref) {
  final width = MediaQuery.of(context).size.width;
  final isWide = width >= kExpandedBreakpoint;

  Future<void> finish(
    BuildContext routeCtx, {
    required bool openSettings,
  }) async {
    await ref.read(settingsProvider.notifier).markAiIntroSeen();
    ref.invalidate(shouldShowAiIntroProvider);
    if (routeCtx.mounted) Navigator.pop(routeCtx);
    if (openSettings && context.mounted) {
      context.push(kSettingsAskPath);
    }
  }

  Widget buildShell(BuildContext routeCtx) {
    return _AskIntroWizardBody(
      isWide: isWide,
      onClose: () => finish(routeCtx, openSettings: false),
      onOpenSettings: () => finish(routeCtx, openSettings: true),
    );
  }

  if (isWide) {
    return showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            child: Container(
              width: 420,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(child: buildShell(ctx)),
            ),
          ),
    );
  }

  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(child: SingleChildScrollView(child: buildShell(ctx)));
    },
  );
}

class _AskIntroWizardBody extends StatefulWidget {
  const _AskIntroWizardBody({
    required this.isWide,
    required this.onClose,
    required this.onOpenSettings,
  });

  final bool isWide;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;

  @override
  State<_AskIntroWizardBody> createState() => _AskIntroWizardBodyState();
}

class _AskIntroWizardBodyState extends State<_AskIntroWizardBody> {
  int _page = 0;

  static const _pageCount = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final page = _pageData(l10n)[_page];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isWide)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: widget.onClose,
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                ),
              ),
            ),
          Icon(LucideIcons.sparkles, size: 40, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            page.body,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (page.bullets.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...page.bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '·',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(b, style: textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
          ],
          if (page.disclaimer != null) ...[
            const SizedBox(height: 8),
            Text(
              page.disclaimer!,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pageCount, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color:
                      active ? colorScheme.primary : colorScheme.outlineVariant,
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          if (_page < _pageCount - 1) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => setState(() => _page += 1),
                child: Text(l10n.askIntroNext),
              ),
            ),
            const SizedBox(height: 8),
            if (_page > 0)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(() => _page -= 1),
                  child: Text(l10n.askIntroBack),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onClose,
                  child: Text(l10n.notNow),
                ),
              ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.onOpenSettings,
                child: Text(l10n.askIntroOpenSettings),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onClose,
                child: Text(l10n.notNow),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_AskIntroPage> _pageData(AppLocalizations l10n) {
    return [
      _AskIntroPage(
        title: l10n.askIntroWelcomeTitle,
        body: l10n.askIntroWelcomeBody,
        bullets: [l10n.askIntroWelcomeBullet1, l10n.askIntroWelcomeBullet2],
      ),
      _AskIntroPage(
        title: l10n.askIntroWhatTitle,
        body: l10n.askIntroWhatBody,
        bullets: [
          l10n.askIntroWhatBullet1,
          l10n.askIntroWhatBullet2,
          l10n.askIntroWhatBullet3,
        ],
      ),
      _AskIntroPage(
        title: l10n.askIntroWhereTitle,
        body: l10n.askIntroWhereBody,
        bullets: [
          l10n.askIntroWhereBullet1,
          l10n.askIntroWhereBullet2,
          l10n.askIntroWhereBullet3,
          l10n.askIntroWhereBullet4,
        ],
      ),
      _AskIntroPage(
        title: l10n.askIntroActivateTitle,
        body: l10n.askIntroActivateBody,
        bullets: [
          l10n.askIntroActivateBullet1,
          l10n.askIntroActivateBullet2,
          l10n.askIntroActivateBullet3,
        ],
        disclaimer: l10n.askIntroActivateDisclaimer,
      ),
    ];
  }
}

class _AskIntroPage {
  const _AskIntroPage({
    required this.title,
    required this.body,
    required this.bullets,
    this.disclaimer,
  });

  final String title;
  final String body;
  final List<String> bullets;
  final String? disclaimer;
}

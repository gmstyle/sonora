import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../settings/providers/settings_category_provider.dart';
import '../../settings/settings_screen_content.dart';
import '../../settings/settings_shared.dart';
import '../tv_metrics.dart';
import '../widgets/tv_focusable.dart';

/// TV settings subset: Appearance, Playback, Downloads, Privacy, About.
///
/// Split left list / right detail (Material TV two-pane). Excludes AI,
/// background, and backup for v1.
class TvSettingsScreen extends ConsumerWidget {
  const TvSettingsScreen({super.key});

  static const _categories = <SettingsCategory>[
    SettingsCategory.appearance,
    SettingsCategory.playback,
    SettingsCategory.downloads,
    SettingsCategory.privacy,
    SettingsCategory.about,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(settingsCategoryProvider);
    final effective = _categories.contains(selected)
        ? selected
        : SettingsCategory.appearance;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 320,
            child: ColoredBox(
              color: colorScheme.surfaceContainerLow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: Row(
                      children: [
                        TvFocusable(
                          onSelect: () => context.pop(),
                          borderRadius: BorderRadius.circular(28),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(LucideIcons.arrowLeft, size: 28),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.settingsLabel,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (var i = 0; i < _categories.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TvFocusable(
                              autofocus: i == 0,
                              onSelect: () => ref
                                  .read(settingsCategoryProvider.notifier)
                                  .select(_categories[i]),
                              borderRadius: BorderRadius.circular(14),
                              child: _TvSettingsNavRow(
                                icon: _categories[i].icon,
                                label: _categories[i].getTitle(context),
                                selected: effective == _categories[i],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(TvMetrics.contentPadding),
              child: SettingsCategoryContent(
                category: effective,
                padding: EdgeInsets.zero,
                sectionSpacing: 24,
                header: SettingsCategoryHeader(category: effective),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avoids [ListTile] ink/Material asserts inside [TvFocusable] chrome.
class _TvSettingsNavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _TvSettingsNavRow({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fg = selected ? colorScheme.primary : colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.secondaryContainer.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: fg,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

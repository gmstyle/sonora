import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/sonora_pulse_tokens.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/settings_category_provider.dart';
import '../settings_screen_content.dart';
import '../settings_shared.dart';
import 'settings_category_rail.dart';

/// Wide (document card) and tablet (full-bleed) Settings split.
class SettingsSplitLayout extends ConsumerWidget {
  const SettingsSplitLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= kExpandedBreakpoint;
    final category = ref.watch(settingsCategoryProvider);
    final l10n = AppLocalizations.of(context)!;
    final lineColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.4);

    final panes = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: isWide ? kSettingsRailWidth : kFacetFilterRailWidth,
          child: const SettingsCategoryRail(),
        ),
        VerticalDivider(width: 1, thickness: 1, color: lineColor),
        Expanded(
          child: SettingsSectionStyleScope(
            style: isWide
                ? SettingsSectionStyle.flat
                : SettingsSectionStyle.card,
            child: SettingsCategoryContent(
              category: category,
              header: SettingsCategoryHeader(
                category: category,
                showBadge: isAndroid && category == SettingsCategory.background,
              ),
              padding: isWide
                  ? const EdgeInsets.fromLTRB(32, 24, 32, 48)
                  : const EdgeInsets.fromLTRB(
                      24,
                      18,
                      kTabletContentPadding,
                      40,
                    ),
              sectionSpacing: 26,
            ),
          ),
        ),
      ],
    );

    final Widget document = isWide
        ? Material(
            color: theme.colorScheme.surfaceContainerLow,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                SonoraPulseTokens.radiusMedia,
              ),
              side: BorderSide(color: lineColor),
            ),
            child: panes,
          )
        : panes;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: isWide
            ? Padding(
                padding: const EdgeInsets.fromLTRB(
                  kWideContentPadding,
                  24,
                  kWideContentPadding,
                  24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kDocumentContentMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SettingsPageHeader(
                          subtitle: l10n.settingsPageSubtitle,
                          dense: false,
                        ),
                        Expanded(child: document),
                      ],
                    ),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kTabletContentPadding,
                      18,
                      kTabletContentPadding,
                      0,
                    ),
                    child: SettingsPageHeader(
                      subtitle: l10n.settingsPageSubtitle,
                      dense: true,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: document,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

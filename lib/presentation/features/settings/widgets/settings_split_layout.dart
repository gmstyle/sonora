import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../shared/widgets/scale_button.dart';
import '../settings_shared.dart';
import '../settings_screen_content.dart';

class SettingsSplitLayout extends StatefulWidget {
  const SettingsSplitLayout({super.key});

  @override
  State<SettingsSplitLayout> createState() => _SettingsSplitLayoutState();
}

class _SettingsSplitLayoutState extends State<SettingsSplitLayout> {
  SettingsCategory _selectedCategory = SettingsCategory.appearance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 1200; // kExpandedBreakpoint

    Widget mainRow = Row(
      children: [
        // Left Pane - Master List (Categories)
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  AppLocalizations.of(context)!.settingsLabel,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: SettingsCategory.values.length,
                  itemBuilder: (context, index) {
                    final category = SettingsCategory.values[index];
                    final isSelected = category == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ScaleButton(
                        onTap: () {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? theme.colorScheme.secondaryContainer
                                        .withValues(alpha: 0.4)
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                category.icon,
                                color:
                                    isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      category.getTitle(context),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight:
                                                isSelected
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                            color:
                                                isSelected
                                                    ? theme.colorScheme.primary
                                                    : theme
                                                        .colorScheme
                                                        .onSurface,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      category.getSubtitle(context),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color:
                                                theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Divider
        VerticalDivider(
          width: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        // Right Pane - Detail Settings
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Detail Header showing category title
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  _selectedCategory.getTitle(context),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SettingsCategoryContent(category: _selectedCategory),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 48.0 : 16.0,
            vertical: isWide ? 32.0 : 16.0,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              color: theme.colorScheme.surfaceContainerLow,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: mainRow,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

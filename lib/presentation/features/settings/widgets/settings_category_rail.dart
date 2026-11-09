import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/sonora_pulse_tokens.dart';
import '../../../../core/utils/platform_utils.dart';
import '../../../shared/widgets/scale_button.dart';
import '../providers/settings_category_provider.dart';
import '../settings_shared.dart';

/// Grouped category rail shared by the wide (260) and tablet (200) split.
///
/// Rows match the Library rail: radius 12, `secondaryContainer` when selected,
/// `bodyMedium`, no border.
class SettingsCategoryRail extends ConsumerWidget {
  const SettingsCategoryRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selected = ref.watch(settingsCategoryProvider);
    final children = <Widget>[];
    var isFirstGroup = true;

    for (final group in SettingsCategoryGroup.values) {
      final categories = group.categories
          .where(
            (category) => category != SettingsCategory.background || isAndroid,
          )
          .toList(growable: false);
      if (categories.isEmpty) continue;

      children.add(
        Padding(
          padding: EdgeInsets.only(
            left: 4,
            right: 4,
            top: isFirstGroup ? 4 : 16,
            bottom: 4,
          ),
          child: Text(
            group.getTitle(context).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );

      for (final category in categories) {
        children.add(
          _SettingsCategoryRailItem(
            category: category,
            selected: category == selected,
          ),
        );
      }

      isFirstGroup = false;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      children: children,
    );
  }
}

class _SettingsCategoryRailItem extends ConsumerWidget {
  const _SettingsCategoryRailItem({
    required this.category,
    required this.selected,
  });

  final SettingsCategory category;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ScaleButton(
        onTap: () =>
            ref.read(settingsCategoryProvider.notifier).select(category),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(SonoraPulseTokens.radiusSm),
          ),
          child: Row(
            children: [
              Icon(category.icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.getTitle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

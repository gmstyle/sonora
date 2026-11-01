import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/utils/platform_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/android_tv_provider.dart';
import '../../../shared/widgets/scale_button.dart';
import '../../tv/widgets/tv_focusable.dart';
import '../settings_screen_content.dart';
import '../settings_shared.dart';

class SettingsSplitLayout extends ConsumerStatefulWidget {
  const SettingsSplitLayout({super.key, this.initialCategory});

  final SettingsCategory? initialCategory;

  @override
  ConsumerState<SettingsSplitLayout> createState() =>
      _SettingsSplitLayoutState();
}

class _SettingsSplitLayoutState extends ConsumerState<SettingsSplitLayout> {
  late SettingsCategory _selectedCategory =
      widget.initialCategory ?? SettingsCategory.appearance;

  late final FocusNode _backFocusNode;
  late final List<FocusNode> _categoryNodes;

  @override
  void initState() {
    super.initState();
    _backFocusNode = FocusNode(debugLabel: 'settings-back');
    // Enough nodes for every category; unused slots stay unused.
    _categoryNodes = List<FocusNode>.generate(
      SettingsCategory.values.length,
      (i) => FocusNode(debugLabel: 'settings-cat-$i'),
      growable: false,
    );
  }

  @override
  void dispose() {
    _backFocusNode.dispose();
    for (final node in _categoryNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _focusSelectedCategory(List<SettingsCategory> categories) {
    final index = categories.indexOf(_selectedCategory);
    final node =
        index >= 0 && index < _categoryNodes.length
            ? _categoryNodes[index]
            : _categoryNodes.first;
    if (node.canRequestFocus) {
      node.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 1200; // kExpandedBreakpoint
    final isTv = ref.watch(isAndroidTvProvider);
    final categories = visibleSettingsCategories(
      isAndroid: isAndroid,
      isAndroidTv: isTv,
    );

    Widget categoryTile(SettingsCategory category, int index) {
      final isSelected = category == _selectedCategory;
      final tile = Container(
        decoration: BoxDecoration(
          color:
              isSelected
                  ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.4)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color:
                          isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category.getSubtitle(context),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
      );

      void select() {
        setState(() => _selectedCategory = category);
        if (isTv) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Dpad.maybeOf(context)?.moveRight();
          });
        }
      }

      if (isTv) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TvFocusable(
            focusNode: _categoryNodes[index],
            autofocus: index == 0,
            entry: isSelected,
            debugLabel: 'settings:${category.name}',
            onSelect: select,
            child: tile,
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ScaleButton(onTap: select, child: tile),
      );
    }

    Widget backControl() {
      if (isTv) {
        return TvFocusable(
          focusNode: _backFocusNode,
          debugLabel: 'settings-back',
          onSelect: () => popSettings(context),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(LucideIcons.arrowLeft, size: 28),
          ),
        );
      }
      return IconButton(
        icon: const Icon(LucideIcons.arrowLeft),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => popSettings(context),
      );
    }

    Widget categoryList = ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: categories.length,
      itemBuilder: (context, index) => categoryTile(categories[index], index),
    );

    if (isTv) {
      categoryList = DpadRegion(
        memoryKey: 'settings/categories',
        debugLabel: 'settings/categories',
        verticalEdge: DpadEdgeBehavior.stop,
        horizontalEdge: DpadEdgeBehavior.leave,
        child: categoryList,
      );
    }

    Widget detailPane = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
    );

    if (isTv) {
      detailPane = DpadRegion(
        memoryKey: 'settings/detail',
        debugLabel: 'settings/detail',
        horizontalEdge: DpadEdgeBehavior.stop,
        verticalEdge: DpadEdgeBehavior.leave,
        onEdge: (direction) {
          if (direction == TraversalDirection.left) {
            _focusSelectedCategory(categories);
          }
        },
        child: detailPane,
      );
    }

    Widget mainRow = Row(
      children: [
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 24, 8),
                child: Row(
                  children: [
                    backControl(),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.settingsLabel,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: categoryList),
            ],
          ),
        ),
        VerticalDivider(
          width: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        Expanded(child: detailPane),
      ],
    );

    // Card + document padding only at >= kExpandedBreakpoint (1200).
    // Tablet 600–1199: full-bleed split on shell surface. TV: full-bleed.
    final Widget body =
        isWide && !isTv
            ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48.0,
                  vertical: 32.0,
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
            )
            : mainRow;

    return Scaffold(backgroundColor: theme.colorScheme.surface, body: body);
  }
}

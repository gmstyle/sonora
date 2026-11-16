import 'package:flutter/services.dart';
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
/// Split left list / right detail (Material TV two-pane) with explicit D-pad
/// Left/Right scope handoff. Excludes AI, background, and backup for v1.
class TvSettingsScreen extends ConsumerStatefulWidget {
  const TvSettingsScreen({super.key});

  static const _categories = <SettingsCategory>[
    SettingsCategory.appearance,
    SettingsCategory.playback,
    SettingsCategory.downloads,
    SettingsCategory.account,
    SettingsCategory.privacy,
    SettingsCategory.about,
  ];

  @override
  ConsumerState<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends ConsumerState<TvSettingsScreen> {
  final FocusScopeNode _leftScope = FocusScopeNode(
    debugLabel: 'tvSettingsLeft',
  );
  final FocusScopeNode _rightScope = FocusScopeNode(
    debugLabel: 'tvSettingsRight',
  );
  late final List<FocusNode> _catNodes;

  @override
  void initState() {
    super.initState();
    _catNodes = List.generate(
      TvSettingsScreen._categories.length,
      (i) => FocusNode(debugLabel: 'tvSettingsCat$i'),
    );
  }

  @override
  void dispose() {
    _leftScope.dispose();
    _rightScope.dispose();
    for (final n in _catNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _enterRightPane() {
    final first = _rightScope.traversalDescendants.firstOrNull;
    if (first != null) {
      first.requestFocus();
    } else {
      _rightScope.requestFocus();
    }
  }

  void _returnToLeftPane(SettingsCategory effective) {
    final idx = TvSettingsScreen._categories.indexOf(effective);
    if (idx >= 0 && idx < _catNodes.length) {
      _catNodes[idx].requestFocus();
    } else {
      _leftScope.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(settingsCategoryProvider);
    final effective = TvSettingsScreen._categories.contains(selected)
        ? selected
        : SettingsCategory.appearance;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: TvColors.bg,
      body: Row(
        children: [
          FocusScope(
            node: _leftScope,
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _enterRightPane();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: SizedBox(
              width: 300,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: TvColors.surface,
                  border: Border(right: BorderSide(color: TvColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                      child: Row(
                        children: [
                          TvFocusable(
                            onSelect: () => context.pop(),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TvColors.border),
                              ),
                              child: const Icon(
                                LucideIcons.chevronLeft,
                                size: 22,
                                color: TvColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.settingsLabel,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: TvColors.textPrimary,
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
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        children: [
                          for (
                            var i = 0;
                            i < TvSettingsScreen._categories.length;
                            i++
                          )
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TvFocusable(
                                focusNode: _catNodes[i],
                                autofocus:
                                    effective ==
                                    TvSettingsScreen._categories[i],
                                onFocusChange: (hasFocus) {
                                  if (hasFocus) {
                                    ref
                                        .read(settingsCategoryProvider.notifier)
                                        .select(
                                          TvSettingsScreen._categories[i],
                                        );
                                  }
                                },
                                onSelect: () {
                                  ref
                                      .read(settingsCategoryProvider.notifier)
                                      .select(TvSettingsScreen._categories[i]);
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => _enterRightPane(),
                                  );
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: _TvSettingsNavRow(
                                  icon: TvSettingsScreen._categories[i].icon,
                                  label: TvSettingsScreen._categories[i]
                                      .getTitle(context),
                                  selected:
                                      effective ==
                                      TvSettingsScreen._categories[i],
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
          ),
          Expanded(
            child: FocusScope(
              node: _rightScope,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.escape ||
                    event.logicalKey == LogicalKeyboardKey.backspace ||
                    event.logicalKey == LogicalKeyboardKey.goBack) {
                  _returnToLeftPane(effective);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  final primary = FocusManager.instance.primaryFocus;
                  if (primary != null &&
                      primary.focusInDirection(TraversalDirection.left)) {
                    return KeyEventResult.handled;
                  }
                  _returnToLeftPane(effective);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
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
    final fg = selected ? colorScheme.primary : TvColors.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.4)
              : TvColors.borderFaint,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: selected ? colorScheme.primary : TvColors.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

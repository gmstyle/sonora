import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/sonora_pulse_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/android_tv_provider.dart';

/// Pops Settings when it was pushed onto the stack; otherwise goes home
/// (deep link `/settings` with nothing to pop).
void popSettings(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}

// ── Section container ────────────────────────────────────────────

/// How a settings pane renders its section groups.
///
/// [compact] is the legacy mobile stack (label + card with side margins).
/// [flat] is the wide document: uppercase label and borderless rows.
/// [card] is the tablet split: uppercase label and a bordered group card.
enum SettingsSectionStyle { compact, flat, card }

/// Lets a layout restyle every [SettingsSection] below it without changing
/// the section widgets themselves.
class SettingsSectionStyleScope extends StatelessWidget {
  const SettingsSectionStyleScope({
    super.key,
    required this.style,
    required this.child,
  });

  final SettingsSectionStyle style;
  final Widget child;

  static SettingsSectionStyle of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_SettingsSectionStyleData>()
            ?.style ??
        SettingsSectionStyle.compact;
  }

  @override
  Widget build(BuildContext context) {
    if (style == SettingsSectionStyle.compact) {
      return _SettingsSectionStyleData(style: style, child: child);
    }

    final theme = Theme.of(context);
    final listTileTheme = ListTileTheme.of(context);
    final groupStyle = style == SettingsSectionStyle.card;
    return _SettingsSectionStyleData(
      style: style,
      child: ListTileTheme(
        data: listTileTheme.copyWith(
          contentPadding: EdgeInsets.symmetric(horizontal: groupStyle ? 14 : 4),
          horizontalTitleGap: groupStyle ? 12 : 14,
          minVerticalPadding: groupStyle ? 9 : 10,
          minLeadingWidth: 20,
        ),
        child: DividerTheme(
          data: DividerTheme.of(context).copyWith(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            thickness: 1,
            space: 1,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SettingsSectionStyleData extends InheritedWidget {
  const _SettingsSectionStyleData({required this.style, required super.child});

  final SettingsSectionStyle style;

  @override
  bool updateShouldNotify(_SettingsSectionStyleData oldWidget) {
    return style != oldWidget.style;
  }
}

class SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final style = SettingsSectionStyleScope.of(context);
    if (style == SettingsSectionStyle.compact) {
      return _buildCompact(context);
    }

    final theme = Theme.of(context);
    final label = Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          fontSize: 10.5,
        ),
      ),
    );

    if (style == SettingsSectionStyle.flat) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label,
          Column(children: children),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label,
        Material(
          color: theme.colorScheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kSettingsSectionRadius),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ── Page and category headers ────────────────────────────────────

/// Unified header for the wide and tablet Settings split.
class SettingsPageHeader extends StatelessWidget {
  const SettingsPageHeader({
    super.key,
    required this.subtitle,
    this.dense = false,
  });

  final String subtitle;

  /// Tablet sizing: smaller title.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final titleStyle = dense
        ? theme.textTheme.titleLarge
        : theme.textTheme.headlineSmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const _SettingsBackButton(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _SettingsBackButton extends StatelessWidget {
  const _SettingsBackButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: () => popSettings(context),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const Icon(LucideIcons.arrowLeft, size: 18),
      style: IconButton.styleFrom(
        minimumSize: const Size(34, 34),
        maximumSize: const Size(34, 34),
        padding: EdgeInsets.zero,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SonoraPulseTokens.radiusSm),
        ),
      ),
    );
  }
}

/// Context header for the selected category in the wide and tablet split.
class SettingsCategoryHeader extends StatelessWidget {
  const SettingsCategoryHeader({
    super.key,
    required this.category,
    this.showBadge = false,
  });

  final SettingsCategory category;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(SonoraPulseTokens.radiusSm),
          ),
          child: Icon(
            category.icon,
            size: 22,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.getTitle(context),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                category.getSubtitle(context),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (showBadge) ...[
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Text(
                    l10n.androidOnly,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Option tiles ─────────────────────────────────────────────────

class SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  const SettingsSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
      secondary: icon != null ? Icon(icon) : null,
    );
  }
}

class SettingsDropdownTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;
  final IconData? icon;

  const SettingsDropdownTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: icon != null ? Icon(icon) : null,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          // Intrinsic width keeps the control compact like a Switch,
          // aligned to the trailing edge of the tile.
          alignment: AlignmentDirectional.centerEnd,
          borderRadius: BorderRadius.circular(8),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          items: options.entries
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          selectedItemBuilder: (context) {
            return options.entries
                .map(
                  (e) => Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        e.value,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ),
                )
                .toList();
          },
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class SettingsButtonTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? trailing;

  const SettingsButtonTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.onPressed,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      leading: icon != null ? Icon(icon) : null,
      trailing: trailing ?? const Icon(LucideIcons.chevronRight),
      onTap: onPressed,
      enabled: onPressed != null,
    );
  }
}

class SettingsSliderTile extends ConsumerWidget {
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double) displayValue;

  const SettingsSliderTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.displayValue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTv = ref.watch(isAndroidTvProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(title),
          subtitle: Text('$subtitle: ${displayValue(value)}'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: isTv
              ? _TvSettingsSlider(
                  value: value,
                  min: min,
                  max: max,
                  displayValue: displayValue,
                  onChanged: onChanged,
                )
              : Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: (max - min).round(),
                  label: displayValue(value),
                  onChanged: onChanged,
                ),
        ),
      ],
    );
  }
}

/// D-pad slider for Android TV: Left/Right step, Up/Down leave focus.
///
/// Material [Slider] traps directional focus and is unusable on leanback.
class _TvSettingsSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double) displayValue;

  const _TvSettingsSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.displayValue,
  });

  @override
  State<_TvSettingsSlider> createState() => _TvSettingsSliderState();
}

class _TvSettingsSliderState extends State<_TvSettingsSlider> {
  final FocusNode _node = FocusNode(debugLabel: 'tvSettingsSlider');
  bool _focused = false;

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  double get _step {
    final span = widget.max - widget.min;
    if (span <= 0) return 1;
    final divisions = span.round().clamp(1, 100);
    return span / divisions;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final next = (widget.value - _step).clamp(widget.min, widget.max);
      widget.onChanged(next);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final next = (widget.value + _step).clamp(widget.min, widget.max);
      widget.onChanged(next);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final span = (widget.max - widget.min).clamp(0.0001, double.infinity);
    final progress = ((widget.value - widget.min) / span).clamp(0.0, 1.0);

    return Focus(
      focusNode: _node,
      onKeyEvent: _onKey,
      onFocusChange: (hasFocus) {
        if (_focused != hasFocus) setState(() => _focused = hasFocus);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused ? colorScheme.primary : Colors.transparent,
            width: 3,
          ),
          color: _focused ? colorScheme.primary.withValues(alpha: 0.08) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.displayValue(widget.value),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── GL / HL code maps ────────────────────────────────────────────

const kCountryCodes = <String, String>{
  'AR': 'Argentina',
  'AU': 'Australia',
  'AT': 'Austria',
  'BE': 'Belgium',
  'BR': 'Brazil',
  'CA': 'Canada',
  'CL': 'Chile',
  'CN': 'China',
  'CO': 'Colombia',
  'HR': 'Croatia',
  'CZ': 'Czech Republic',
  'DK': 'Denmark',
  'EG': 'Egypt',
  'FI': 'Finland',
  'FR': 'France',
  'DE': 'Germany',
  'GR': 'Greece',
  'HK': 'Hong Kong',
  'HU': 'Hungary',
  'IN': 'India',
  'ID': 'Indonesia',
  'IE': 'Ireland',
  'IL': 'Israel',
  'IT': 'Italy',
  'JP': 'Japan',
  'KE': 'Kenya',
  'MY': 'Malaysia',
  'MX': 'Mexico',
  'NL': 'Netherlands',
  'NZ': 'New Zealand',
  'NG': 'Nigeria',
  'NO': 'Norway',
  'PE': 'Peru',
  'PH': 'Philippines',
  'PL': 'Poland',
  'PT': 'Portugal',
  'RO': 'Romania',
  'RU': 'Russia',
  'SA': 'Saudi Arabia',
  'SG': 'Singapore',
  'ZA': 'South Africa',
  'KR': 'South Korea',
  'ES': 'Spain',
  'SE': 'Sweden',
  'CH': 'Switzerland',
  'TW': 'Taiwan',
  'TH': 'Thailand',
  'TR': 'Turkey',
  'UA': 'Ukraine',
  'AE': 'United Arab Emirates',
  'GB': 'United Kingdom',
  'US': 'United States',
  'VN': 'Vietnam',
};

const kLanguageCodes = <String, String>{
  'ar': 'Arabic',
  'bg': 'Bulgarian',
  'ca': 'Catalan',
  'zh': 'Chinese',
  'hr': 'Croatian',
  'cs': 'Czech',
  'da': 'Danish',
  'nl': 'Dutch',
  'en': 'English',
  'et': 'Estonian',
  'fil': 'Filipino',
  'fi': 'Finnish',
  'fr': 'French',
  'de': 'German',
  'el': 'Greek',
  'he': 'Hebrew',
  'hi': 'Hindi',
  'hu': 'Hungarian',
  'id': 'Indonesian',
  'it': 'Italian',
  'ja': 'Japanese',
  'ko': 'Korean',
  'lv': 'Latvian',
  'lt': 'Lithuanian',
  'ms': 'Malay',
  'no': 'Norwegian',
  'pl': 'Polish',
  'pt': 'Portuguese',
  'ro': 'Romanian',
  'ru': 'Russian',
  'sr': 'Serbian',
  'sk': 'Slovak',
  'sl': 'Slovenian',
  'es': 'Spanish',
  'sv': 'Swedish',
  'th': 'Thai',
  'tr': 'Turkish',
  'uk': 'Ukrainian',
  'vi': 'Vietnamese',
};

// ── Settings categories ──────────────────────────────────────────

enum SettingsCategory {
  appearance,
  playback,
  downloads,
  ai,
  background,
  privacy,
  backup,
  about,
}

/// Rail grouping used by the wide and tablet split.
enum SettingsCategoryGroup { lookAndFeel, playback, assistant, data, about }

extension SettingsCategoryGroupExtension on SettingsCategoryGroup {
  String getTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case SettingsCategoryGroup.lookAndFeel:
        return l10n.settingsGroupLookAndFeel;
      case SettingsCategoryGroup.playback:
        return l10n.playback;
      case SettingsCategoryGroup.assistant:
        return l10n.settingsGroupAssistant;
      case SettingsCategoryGroup.data:
        return l10n.settingsGroupData;
      case SettingsCategoryGroup.about:
        return l10n.about;
    }
  }

  List<SettingsCategory> get categories {
    switch (this) {
      case SettingsCategoryGroup.lookAndFeel:
        return const [SettingsCategory.appearance];
      case SettingsCategoryGroup.playback:
        return const [
          SettingsCategory.playback,
          SettingsCategory.downloads,
          SettingsCategory.background,
        ];
      case SettingsCategoryGroup.assistant:
        return const [SettingsCategory.ai];
      case SettingsCategoryGroup.data:
        return const [SettingsCategory.privacy, SettingsCategory.backup];
      case SettingsCategoryGroup.about:
        return const [SettingsCategory.about];
    }
  }
}

/// Query value for `/settings?section=ask` (and future section deep links).
const kSettingsAskSection = 'ask';

/// Path that opens Settings already on the Ask category.
const kSettingsAskPath = '/settings?section=$kSettingsAskSection';

/// Maps a `section` query param to a [SettingsCategory], or `null` if unknown.
SettingsCategory? settingsCategoryFromSection(String? section) {
  if (section == null || section.isEmpty) return null;
  for (final category in SettingsCategory.values) {
    if (category.sectionSlug == section) return category;
  }
  switch (section) {
    case kSettingsAskSection:
      return SettingsCategory.ai;
    default:
      return null;
  }
}

extension SettingsCategoryExtension on SettingsCategory {
  /// Stable `?section=` value for this category.
  String get sectionSlug {
    switch (this) {
      case SettingsCategory.appearance:
        return 'appearance';
      case SettingsCategory.playback:
        return 'playback';
      case SettingsCategory.downloads:
        return 'downloads';
      case SettingsCategory.ai:
        return 'ai';
      case SettingsCategory.background:
        return 'background';
      case SettingsCategory.privacy:
        return 'privacy';
      case SettingsCategory.backup:
        return 'backup';
      case SettingsCategory.about:
        return 'about';
    }
  }

  String getTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case SettingsCategory.appearance:
        return l10n.appearance;
      case SettingsCategory.playback:
        return l10n.playback;
      case SettingsCategory.downloads:
        return l10n.downloadsSettings;
      case SettingsCategory.ai:
        return l10n.aiSettings;
      case SettingsCategory.background:
        return l10n.backgroundPlayback;
      case SettingsCategory.privacy:
        return l10n.privacy;
      case SettingsCategory.backup:
        return l10n.backupRestore;
      case SettingsCategory.about:
        return l10n.about;
    }
  }

  String getSubtitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case SettingsCategory.appearance:
        return l10n.settingsAppearanceSubtitle;
      case SettingsCategory.playback:
        return l10n.settingsPlaybackSubtitle;
      case SettingsCategory.downloads:
        return l10n.settingsDownloadsSubtitle;
      case SettingsCategory.ai:
        return l10n.aiSettingsSubtitle;
      case SettingsCategory.background:
        return l10n.settingsBackgroundSubtitle;
      case SettingsCategory.privacy:
        return l10n.settingsPrivacySubtitle;
      case SettingsCategory.backup:
        return l10n.settingsBackupSubtitle;
      case SettingsCategory.about:
        return l10n.settingsAboutSubtitle;
    }
  }

  IconData get icon {
    switch (this) {
      case SettingsCategory.appearance:
        return LucideIcons.palette;
      case SettingsCategory.playback:
        return LucideIcons.sliders;
      case SettingsCategory.downloads:
        return LucideIcons.download;
      case SettingsCategory.ai:
        return LucideIcons.sparkles;
      case SettingsCategory.background:
        return LucideIcons.batteryFull;
      case SettingsCategory.privacy:
        return LucideIcons.shield;
      case SettingsCategory.backup:
        return LucideIcons.refreshCw;
      case SettingsCategory.about:
        return LucideIcons.info;
    }
  }
}

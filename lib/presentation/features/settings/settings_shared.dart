import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers/android_tv_provider.dart';
import '../tv/widgets/tv_focusable.dart';

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

// ── Option tiles ─────────────────────────────────────────────────

class SettingsSwitchTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final tile = SwitchListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
      secondary: icon != null ? Icon(icon) : null,
    );
    if (!ref.watch(isAndroidTvProvider)) return tile;
    return TvFocusable(
      debugLabel: 'settings-switch:$title',
      onSelect: () => onChanged(!value),
      child: tile,
    );
  }
}

class SettingsDropdownTile extends ConsumerWidget {
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

  Future<void> _pickOnTv(BuildContext context) async {
    final keys = options.keys.toList(growable: false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
            child: DpadRegion(
              memoryKey: 'settings/dropdown',
              debugLabel: 'settings/dropdown:$title',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Text(
                      title,
                      style: Theme.of(dialogContext).textTheme.titleLarge,
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: keys.length,
                      itemBuilder: (context, index) {
                        final key = keys[index];
                        final selected = key == value;
                        final selectedIndex = keys.indexOf(value);
                        final autofocusIndex =
                            selectedIndex >= 0 ? selectedIndex : 0;
                        return TvFocusable(
                          autofocus: index == autofocusIndex,
                          debugLabel: 'settings-dropdown-option:$key',
                          onSelect: () {
                            onChanged(key);
                            Navigator.of(dialogContext).pop();
                          },
                          child: ListTile(
                            title: Text(options[key]!),
                            selected: selected,
                            trailing:
                                selected ? const Icon(LucideIcons.check) : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isTv = ref.watch(isAndroidTvProvider);
    final tile = ListTile(
      leading: icon != null ? Icon(icon) : null,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing:
          isTv
              ? Text(options[value] ?? value, style: theme.textTheme.bodyMedium)
              : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  // Intrinsic width keeps the control compact like a Switch,
                  // aligned to the trailing edge of the tile.
                  alignment: AlignmentDirectional.centerEnd,
                  borderRadius: BorderRadius.circular(8),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  items:
                      options.entries
                          .map(
                            (e) => DropdownMenuItem<String>(
                              value: e.key,
                              child: Text(
                                e.value,
                                overflow: TextOverflow.ellipsis,
                              ),
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
    if (!isTv) return tile;
    return TvFocusable(
      debugLabel: 'settings-dropdown:$title',
      onSelect: () => _pickOnTv(context),
      child: tile,
    );
  }
}

class SettingsButtonTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final tile = ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      leading: icon != null ? Icon(icon) : null,
      trailing: trailing ?? const Icon(LucideIcons.chevronRight),
      onTap: onPressed,
      enabled: onPressed != null,
    );
    if (!ref.watch(isAndroidTvProvider) || onPressed == null) return tile;
    return TvFocusable(
      debugLabel: 'settings-button:$title',
      onSelect: onPressed,
      child: tile,
    );
  }
}

class SettingsSliderTile extends ConsumerStatefulWidget {
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
  ConsumerState<SettingsSliderTile> createState() => _SettingsSliderTileState();
}

class _SettingsSliderTileState extends ConsumerState<SettingsSliderTile> {
  bool _editing = false;

  double get _step {
    final divisions = (widget.max - widget.min).round();
    if (divisions <= 0) return 1;
    return (widget.max - widget.min) / divisions;
  }

  void _nudge(TraversalDirection direction) {
    final delta =
        direction == TraversalDirection.right ||
                direction == TraversalDirection.down
            ? _step
            : -_step;
    final next = (widget.value + delta).clamp(widget.min, widget.max);
    if (next != widget.value) {
      widget.onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTv = ref.watch(isAndroidTvProvider);
    final tile = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(widget.title),
          subtitle: Text(
            '${widget.subtitle}: ${widget.displayValue(widget.value)}',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Slider(
            value: widget.value,
            min: widget.min,
            max: widget.max,
            divisions: (widget.max - widget.min).round(),
            label: widget.displayValue(widget.value),
            onChanged: widget.onChanged,
          ),
        ),
      ],
    );

    if (!isTv) return tile;

    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _editing) {
          setState(() => _editing = false);
        }
      },
      child: TvFocusable(
        debugLabel: 'settings-slider:${widget.title}',
        onFocusChange: (focused) {
          if (!focused && _editing) {
            setState(() => _editing = false);
          }
        },
        onSelect: () => setState(() => _editing = !_editing),
        onDirection: (direction) {
          if (!_editing) return false;
          if (direction == TraversalDirection.left ||
              direction == TraversalDirection.right) {
            _nudge(direction);
            return true;
          }
          return false;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _editing ? theme.colorScheme.tertiary : Colors.transparent,
              width: 2,
            ),
          ),
          child: tile,
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

/// Categories shown in Settings. Hides the battery/background category on Android TV.
List<SettingsCategory> visibleSettingsCategories({
  required bool isAndroid,
  required bool isAndroidTv,
}) {
  return SettingsCategory.values
      .where((c) {
        if (c == SettingsCategory.background) {
          return isAndroid && !isAndroidTv;
        }
        return true;
      })
      .toList(growable: false);
}

/// Query value for `/settings?section=ask` (and future section deep links).
const kSettingsAskSection = 'ask';

/// Path that opens Settings already on the Ask category.
const kSettingsAskPath = '/settings?section=$kSettingsAskSection';

/// Maps a `section` query param to a [SettingsCategory], or `null` if unknown.
SettingsCategory? settingsCategoryFromSection(String? section) {
  switch (section) {
    case kSettingsAskSection:
      return SettingsCategory.ai;
    default:
      return null;
  }
}

extension SettingsCategoryExtension on SettingsCategory {
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
    final isIt = Localizations.localeOf(context).languageCode == 'it';
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case SettingsCategory.appearance:
        return isIt
            ? 'Tema, AMOLED, colori e stile del vinile'
            : 'Theme, AMOLED, colors and vinyl style';
      case SettingsCategory.playback:
        return isIt
            ? 'Dissolvenza, Up Next, paese e lingua'
            : 'Crossfade, Up Next, country and language';
      case SettingsCategory.downloads:
        return isIt
            ? 'Cartella, Wi-Fi e spazio disco'
            : 'Folder, Wi-Fi and disk space';
      case SettingsCategory.ai:
        return l10n.aiSettingsSubtitle;
      case SettingsCategory.background:
        return isIt
            ? 'Ottimizzazione batteria per riproduzione in background'
            : 'Battery optimization for background playback';
      case SettingsCategory.privacy:
        return isIt
            ? 'Cronologia di ascolto e ricerca'
            : 'Listening and search history';
      case SettingsCategory.backup:
        return isIt
            ? 'Esportazione, importazione e sincronizzazione locale'
            : 'Export, import and local synchronization';
      case SettingsCategory.about:
        return isIt
            ? 'Versione, licenze, aggiornamenti e donazioni'
            : 'Version, licenses, updates and donations';
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

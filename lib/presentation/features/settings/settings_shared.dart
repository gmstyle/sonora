import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';

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
  final String value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  const SettingsDropdownTile({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(options[value] ?? value),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items:
            options.entries
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class SettingsButtonTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onPressed;
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
    );
  }
}

class SettingsSliderTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(title),
          subtitle: Text('$subtitle: ${displayValue(value)}'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Slider(
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
  privacy,
  backup,
  about,
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
            ? 'Cartella, Wi-Fi e batteria background'
            : 'Folder, Wi-Fi and background battery';
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
      case SettingsCategory.privacy:
        return LucideIcons.shield;
      case SettingsCategory.backup:
        return LucideIcons.refreshCw;
      case SettingsCategory.about:
        return LucideIcons.info;
    }
  }
}

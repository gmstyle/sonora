import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';

class AskGuidedAction {
  const AskGuidedAction({
    required this.icon,
    required this.title,
    required this.prompt,
  });

  final IconData icon;
  final String title;
  final String prompt;
}

List<AskGuidedAction> buildAskGuidedActions(AppLocalizations l10n) => [
  AskGuidedAction(
    icon: LucideIcons.listMusic,
    title: l10n.askGuidedMixTitle,
    prompt: l10n.askGuidedMixPrompt,
  ),
  AskGuidedAction(
    icon: LucideIcons.compass,
    title: l10n.askGuidedDiscoverTitle,
    prompt: l10n.askGuidedDiscoverPrompt,
  ),
  AskGuidedAction(
    icon: LucideIcons.listPlus,
    title: l10n.askGuidedPlaylistTitle,
    prompt: l10n.askGuidedPlaylistPrompt,
  ),
  AskGuidedAction(
    icon: LucideIcons.trendingUp,
    title: l10n.askGuidedTasteTitle,
    prompt: l10n.askGuidedTastePrompt,
  ),
];

/// Quick guided-action buttons shown either as vertical tiles in the desktop
/// filter rail or as pill cards on the empty Ask hub.
class AskGuidedActions extends StatelessWidget {
  const AskGuidedActions({
    super.key,
    required this.enabled,
    required this.onSelectPrompt,
    this.verticalList = false,
  });

  final bool enabled;
  final ValueChanged<String> onSelectPrompt;
  final bool verticalList;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final actions = buildAskGuidedActions(l10n);

    if (verticalList) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              l10n.askGuidedHeader,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final action in actions)
            ListTile(
              dense: true,
              enabled: enabled,
              leading: Icon(action.icon, size: 18, color: cs.primary),
              title: Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: enabled ? () => onSelectPrompt(action.prompt) : null,
            ),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final action in actions)
          ActionChip(
            avatar: Icon(
              action.icon,
              size: 16,
              color: enabled ? cs.primary : cs.onSurfaceVariant,
            ),
            label: Text(action.title),
            onPressed: enabled ? () => onSelectPrompt(action.prompt) : null,
          ),
      ],
    );
  }
}

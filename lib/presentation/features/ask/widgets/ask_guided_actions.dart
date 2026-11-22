import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../l10n/app_localizations.dart';

enum AskGuidedActionKind {
  tailoredMix,
  expandPlaylist,
  discoverArtists,
  buildPlaylist,
  tasteVibe,
}

class AskGuidedAction {
  const AskGuidedAction({
    required this.kind,
    required this.icon,
    required this.title,
    required this.prompt,
  });

  final AskGuidedActionKind kind;
  final IconData icon;
  final String title;
  final String prompt;
}

List<AskGuidedAction> buildAskGuidedActions(AppLocalizations l10n) => [
  AskGuidedAction(
    kind: AskGuidedActionKind.tailoredMix,
    icon: LucideIcons.listMusic,
    title: l10n.askGuidedMixTitle,
    prompt: l10n.askGuidedMixPrompt,
  ),
  AskGuidedAction(
    kind: AskGuidedActionKind.expandPlaylist,
    icon: LucideIcons.listPlus,
    title: l10n.askGuidedExpandPlaylistTitle,
    prompt: l10n.askGuidedExpandPlaylistPrompt,
  ),
  AskGuidedAction(
    kind: AskGuidedActionKind.discoverArtists,
    icon: LucideIcons.compass,
    title: l10n.askGuidedDiscoverTitle,
    prompt: l10n.askGuidedDiscoverPrompt,
  ),
  AskGuidedAction(
    kind: AskGuidedActionKind.buildPlaylist,
    icon: LucideIcons.sparkles,
    title: l10n.askGuidedPlaylistTitle,
    prompt: l10n.askGuidedPlaylistPrompt,
  ),
  AskGuidedAction(
    kind: AskGuidedActionKind.tasteVibe,
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
    this.onOpenMixBuilder,
    this.onOpenExpandPlaylist,
    this.verticalList = false,
  });

  final bool enabled;
  final ValueChanged<String> onSelectPrompt;
  final VoidCallback? onOpenMixBuilder;
  final VoidCallback? onOpenExpandPlaylist;
  final bool verticalList;

  VoidCallback? _onTapFor(AskGuidedAction action) {
    if (!enabled) return null;
    return switch (action.kind) {
      AskGuidedActionKind.tailoredMix when onOpenMixBuilder != null =>
        onOpenMixBuilder,
      AskGuidedActionKind.expandPlaylist when onOpenExpandPlaylist != null =>
        onOpenExpandPlaylist,
      _ => () => onSelectPrompt(action.prompt),
    };
  }

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
              onTap: _onTapFor(action),
            ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in actions)
          ActionChip(
            avatar: Icon(
              action.icon,
              size: 16,
              color: enabled ? cs.primary : cs.onSurfaceVariant,
            ),
            label: Text(action.title),
            visualDensity: VisualDensity.compact,
            onPressed: _onTapFor(action),
          ),
      ],
    );
  }
}

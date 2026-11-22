import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../domain/models/ask_chat_models.dart';
import '../../../../l10n/app_localizations.dart';

class AskFollowUpSuggestion {
  const AskFollowUpSuggestion({
    required this.icon,
    required this.label,
    required this.prompt,
  });

  final IconData icon;
  final String label;
  final String prompt;
}

List<AskFollowUpSuggestion> buildAskFollowUpSuggestions(
  AskChatMessage message,
  AppLocalizations l10n,
) {
  if (message.isUser) return const [];

  final mixes = message.attachments.whereType<AskMixAttachment>().toList();
  if (mixes.isNotEmpty) {
    final mix = mixes.first;
    final title = mix.title.trim().isEmpty ? 'Mix' : mix.title.trim();
    return [
      if (mix.tracks.length < 35)
        AskFollowUpSuggestion(
          icon: LucideIcons.listPlus,
          label: l10n.askFollowUpExpand40,
          prompt: l10n.askFollowUpExpand40Prompt(title),
        ),
      AskFollowUpSuggestion(
        icon: LucideIcons.moon,
        label: l10n.askFollowUpCalmer,
        prompt: l10n.askFollowUpCalmerPrompt,
      ),
      AskFollowUpSuggestion(
        icon: LucideIcons.zap,
        label: l10n.askFollowUpEnergetic,
        prompt: l10n.askFollowUpEnergeticPrompt,
      ),
    ];
  }

  final proposals = message.attachments
      .whereType<AskPlaylistWriteProposal>()
      .toList();
  if (proposals.isNotEmpty) {
    final proposal = proposals.first;
    final name = proposal.playlistName.trim().isEmpty
        ? 'Playlist'
        : proposal.playlistName.trim();
    return [
      AskFollowUpSuggestion(
        icon: LucideIcons.listPlus,
        label: l10n.askFollowUpAddMore15,
        prompt: l10n.askFollowUpAddMore15Prompt(name),
      ),
      if (proposal.operation != 'remove')
        AskFollowUpSuggestion(
          icon: LucideIcons.sparkles,
          label: l10n.askFollowUpSimilarArtists,
          prompt: l10n.askFollowUpSimilarArtistsPrompt,
        ),
    ];
  }

  if (message.attachments.any((a) => a is AskArtistsAttachment)) {
    return [
      AskFollowUpSuggestion(
        icon: LucideIcons.listMusic,
        label: l10n.askFollowUpMixArtists,
        prompt: l10n.askFollowUpMixArtistsPrompt,
      ),
      AskFollowUpSuggestion(
        icon: LucideIcons.disc3,
        label: l10n.askFollowUpBestAlbums,
        prompt: l10n.askFollowUpBestAlbumsPrompt,
      ),
      AskFollowUpSuggestion(
        icon: LucideIcons.compass,
        label: l10n.askFollowUpSimilarArtists,
        prompt: l10n.askFollowUpSimilarArtistsPrompt,
      ),
    ];
  }

  if (message.attachments.any(
    (a) =>
        a is AskAlbumsAttachment ||
        a is AskTracksAttachment ||
        a is AskPlaylistsAttachment,
  )) {
    return [
      AskFollowUpSuggestion(
        icon: LucideIcons.listMusic,
        label: l10n.askFollowUpTurnIntoMix,
        prompt: l10n.askFollowUpTurnIntoMixPrompt,
      ),
      AskFollowUpSuggestion(
        icon: LucideIcons.compass,
        label: l10n.askFollowUpSimilarArtists,
        prompt: l10n.askFollowUpSimilarArtistsPrompt,
      ),
      AskFollowUpSuggestion(
        icon: LucideIcons.zap,
        label: l10n.askFollowUpEnergetic,
        prompt: l10n.askFollowUpEnergeticPrompt,
      ),
    ];
  }

  if (message.attachments.any(
    (a) => a is AskPodcastsAttachment || a is AskEpisodesAttachment,
  )) {
    return [
      AskFollowUpSuggestion(
        icon: LucideIcons.mic,
        label: l10n.askFollowUpMorePodcasts,
        prompt: l10n.askFollowUpMorePodcastsPrompt,
      ),
      AskFollowUpSuggestion(
        icon: LucideIcons.compass,
        label: l10n.askFollowUpSimilarArtists,
        prompt: l10n.askFollowUpSimilarArtistsPrompt,
      ),
    ];
  }

  return [
    AskFollowUpSuggestion(
      icon: LucideIcons.listMusic,
      label: l10n.askFollowUpMixThisMood,
      prompt: l10n.askFollowUpMixThisMoodPrompt,
    ),
    AskFollowUpSuggestion(
      icon: LucideIcons.compass,
      label: l10n.askFollowUpSimilarArtists,
      prompt: l10n.askFollowUpSimilarArtistsPrompt,
    ),
  ];
}

class AskFollowUpChips extends StatelessWidget {
  const AskFollowUpChips({
    super.key,
    required this.message,
    required this.enabled,
    required this.onSelectPrompt,
  });

  final AskChatMessage message;
  final bool enabled;
  final ValueChanged<String> onSelectPrompt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final suggestions = buildAskFollowUpSuggestions(message, l10n);
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in suggestions)
            ActionChip(
              avatar: Icon(
                item.icon,
                size: 15,
                color: enabled ? cs.primary : cs.onSurfaceVariant,
              ),
              label: Text(item.label),
              visualDensity: VisualDensity.compact,
              onPressed: enabled ? () => onSelectPrompt(item.prompt) : null,
            ),
        ],
      ),
    );
  }
}

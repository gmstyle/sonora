import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../domain/models/ask_chat_models.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../providers/ask_chat_provider.dart';

List<PlaylistEntryModel> _entriesFromRefs(List<AskTrackRef> tracks) {
  return [
    for (var i = 0; i < tracks.length; i++)
      PlaylistEntryModel(
        playlistId: 0,
        videoId: tracks[i].videoId,
        position: i,
        title: tracks[i].title,
        artist: tracks[i].artist,
        artistsJson: tracks[i].artistsJson,
        thumbnailUrl: tracks[i].thumbnailUrl,
        duration: tracks[i].durationSec,
        isExplicit: tracks[i].isExplicit,
      ),
  ];
}

class AskRichAttachments extends StatelessWidget {
  const AskRichAttachments({super.key, required this.message});

  final AskChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.attachments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < message.attachments.length; i++) ...[
          const SizedBox(height: 10),
          switch (message.attachments[i]) {
            final AskMixAttachment mix => AskMixCard(
              message: message,
              attachmentIndex: i,
              mix: mix,
            ),
            final AskPlaylistWriteProposal prop => AskPlaylistProposalCard(
              message: message,
              attachmentIndex: i,
              proposal: prop,
            ),
            final AskArtistsAttachment artists => AskArtistsCard(
              attachment: artists,
            ),
            final AskInsightsAttachment insights => AskInsightsCard(
              attachment: insights,
            ),
          },
        ],
      ],
    );
  }
}

class AskMixCard extends ConsumerStatefulWidget {
  const AskMixCard({
    super.key,
    required this.message,
    required this.attachmentIndex,
    required this.mix,
  });

  final AskChatMessage message;
  final int attachmentIndex;
  final AskMixAttachment mix;

  @override
  ConsumerState<AskMixCard> createState() => _AskMixCardState();
}

class _AskMixCardState extends ConsumerState<AskMixCard> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isOffline = ref.watch(isOfflineProvider);
    final mix = widget.mix;
    final saved = mix.savedPlaylistId != null;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.listMusic, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mix.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  l10n.askTracksCount(mix.tracks.length),
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            if (mix.subtitle != null && mix.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                mix.subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            for (var i = 0; i < mix.tracks.length.clamp(0, 6); i++)
              _TrackPreviewRow(
                track: mix.tracks[i],
                enabled: !isOffline,
                onTap: () => ref
                    .read(playerStateProvider.notifier)
                    .playLocalPlaylist(
                      _entriesFromRefs(mix.tracks),
                      startIndex: i,
                    ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: isOffline || mix.tracks.isEmpty
                      ? null
                      : () => ref
                            .read(playerStateProvider.notifier)
                            .playLocalPlaylist(_entriesFromRefs(mix.tracks)),
                  icon: const Icon(LucideIcons.play, size: 16),
                  label: Text(l10n.askActionPlay),
                ),
                if (saved)
                  Chip(
                    avatar: Icon(
                      LucideIcons.check,
                      size: 16,
                      color: cs.primary,
                    ),
                    label: Text(l10n.askSavedStatus),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () => _confirmSave(context),
                    icon: const Icon(LucideIcons.save, size: 16),
                    label: Text(l10n.askActionSavePlaylist),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSave(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: widget.mix.title);
    final chosenName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.askSaveDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.askPlaylistNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.askActionConfirmSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (chosenName == null || chosenName.isEmpty || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(askChatProvider.notifier)
          .confirmSaveMix(
            message: widget.message,
            attachmentIndex: widget.attachmentIndex,
            customName: chosenName,
          );
      if (mounted) {
        ref
            .read(actionFeedbackProvider.notifier)
            .report(l10n.momentMixSaved(chosenName));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class AskPlaylistProposalCard extends ConsumerStatefulWidget {
  const AskPlaylistProposalCard({
    super.key,
    required this.message,
    required this.attachmentIndex,
    required this.proposal,
  });

  final AskChatMessage message;
  final int attachmentIndex;
  final AskPlaylistWriteProposal proposal;

  @override
  ConsumerState<AskPlaylistProposalCard> createState() =>
      _AskPlaylistProposalCardState();
}

class _AskPlaylistProposalCardState
    extends ConsumerState<AskPlaylistProposalCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isOffline = ref.watch(isOfflineProvider);
    final p = widget.proposal;

    final opLabel = switch (p.operation) {
      'append' => l10n.askPlaylistOpAppend,
      'remove' => l10n.askPlaylistOpRemove,
      _ => l10n.askPlaylistOpCreate,
    };

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(
              avatar: Icon(LucideIcons.listPlus, size: 15, color: cs.primary),
              label: Text(opLabel),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.playlistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  l10n.askTracksCount(p.tracks.length),
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < p.tracks.length.clamp(0, 6); i++)
              _TrackPreviewRow(
                track: p.tracks[i],
                enabled: !isOffline,
                onTap: () => ref
                    .read(playerStateProvider.notifier)
                    .playLocalPlaylist(
                      _entriesFromRefs(p.tracks),
                      startIndex: i,
                    ),
              ),
            const SizedBox(height: 12),
            if (p.isPending)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              await ref
                                  .read(askChatProvider.notifier)
                                  .confirmPlaylistProposal(
                                    message: widget.message,
                                    attachmentIndex: widget.attachmentIndex,
                                  );
                              if (context.mounted) {
                                ref
                                    .read(actionFeedbackProvider.notifier)
                                    .report(
                                      l10n.momentMixSaved(p.playlistName),
                                    );
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: Text(l10n.askActionConfirmSave),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => ref
                              .read(askChatProvider.notifier)
                              .discardPlaylistProposal(
                                message: widget.message,
                                attachmentIndex: widget.attachmentIndex,
                              ),
                    icon: const Icon(LucideIcons.x, size: 16),
                    label: Text(l10n.askActionDiscard),
                  ),
                ],
              )
            else
              Chip(
                avatar: Icon(
                  p.status == 'saved' ? LucideIcons.check : LucideIcons.x,
                  size: 16,
                  color: p.status == 'saved' ? cs.primary : cs.onSurfaceVariant,
                ),
                label: Text(
                  p.status == 'saved'
                      ? l10n.askSavedStatus
                      : l10n.askDiscardedStatus,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AskArtistsCard extends StatelessWidget {
  const AskArtistsCard({super.key, required this.attachment});

  final AskArtistsAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attachment.title.isNotEmpty) ...[
              Text(
                attachment.title,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final artist in attachment.artists)
                  ActionChip(
                    avatar: const Icon(LucideIcons.user, size: 16),
                    label: Text(artist.name),
                    onPressed: artist.artistId.isEmpty
                        ? null
                        : () => context.push('/artist/${artist.artistId}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AskInsightsCard extends StatelessWidget {
  const AskInsightsCard({super.key, required this.attachment});

  final AskInsightsAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attachment.title.isNotEmpty) ...[
              Text(
                attachment.title,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
            ],
            for (final bullet in attachment.bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $bullet', style: tt.bodySmall),
              ),
            if (attachment.sources.isNotEmpty) ...[
              if (attachment.bullets.isNotEmpty) const SizedBox(height: 8),
              Text(
                l10n.askSourcesLabel,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final source in attachment.sources)
                    ActionChip(
                      avatar: const Icon(LucideIcons.externalLink, size: 14),
                      label: Text(source.displayTitle),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final uri = Uri.tryParse(source.uri);
                        if (uri != null) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackPreviewRow extends StatelessWidget {
  const _TrackPreviewRow({
    required this.track,
    required this.enabled,
    required this.onTap,
  });

  final AskTrackRef track;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        child: Row(
          children: [
            ThumbnailWidget(
              imageUrl: track.thumbnailUrl,
              size: 38,
              borderRadius: 8,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium,
                  ),
                  if (track.artist.isNotEmpty)
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Icon(LucideIcons.play, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

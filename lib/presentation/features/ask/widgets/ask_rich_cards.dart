import 'dart:async';

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
import '../../../providers/play_local_playlist_use_case_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../shared/widgets/album_card.dart';
import '../../../shared/widgets/artist_card.dart';
import '../../../shared/widgets/context_menu_sheet.dart';
import '../../../shared/widgets/episode_tile.dart';
import '../../../shared/widgets/hover_carousel_arrows.dart';
import '../../../shared/widgets/playlist_card.dart';
import '../../../shared/widgets/podcast_tile.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../library/providers/library_provider.dart';
import '../../library/widgets/playlist_detail_view.dart';
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
        isVideo: tracks[i].isVideo,
        duration: tracks[i].durationSec,
        isExplicit: tracks[i].isExplicit,
      ),
  ];
}

Future<void> _enqueueTracks(
  BuildContext context,
  WidgetRef ref,
  List<AskTrackRef> tracks,
) async {
  final l10n = AppLocalizations.of(context)!;
  final items = await ref
      .read(playLocalPlaylistUseCaseProvider)
      .execute(_entriesFromRefs(tracks), playIndex: -1);
  if (!context.mounted || items.isEmpty) return;
  await ref.read(playerStateProvider.notifier).addAllToQueue(items);
  ref
      .read(actionFeedbackProvider.notifier)
      .report(l10n.addedToQueue(items.length));
}

void _openSavedPlaylist(
  BuildContext context,
  WidgetRef ref,
  int playlistId,
  String fallbackName,
) {
  final loaded = ref.read(playlistsProvider).asData?.value ?? const [];
  final match = loaded.cast<LocalPlaylistModel?>().firstWhere(
    (p) => p?.id == playlistId,
    orElse: () => null,
  );
  final model =
      match ??
      LocalPlaylistModel(
        id: playlistId,
        name: fallbackName,
        createdAt: DateTime.now(),
      );
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlaylistDetailView(
        playlist: model,
        onUpdated: () => ref.invalidate(playlistsProvider),
      ),
    ),
  );
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
            final AskTracksAttachment tracks => AskTracksCard(
              attachment: tracks,
            ),
            final AskArtistsAttachment artists => AskArtistsCard(
              messageId: message.id,
              attachmentIndex: i,
              attachment: artists,
            ),
            final AskAlbumsAttachment albums => AskAlbumsCard(
              messageId: message.id,
              attachmentIndex: i,
              attachment: albums,
            ),
            final AskPlaylistsAttachment playlists => AskPlaylistsCard(
              messageId: message.id,
              attachmentIndex: i,
              attachment: playlists,
            ),
            final AskPodcastsAttachment podcasts => AskPodcastsCard(
              attachment: podcasts,
            ),
            final AskEpisodesAttachment episodes => AskEpisodesCard(
              attachment: episodes,
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
            const SizedBox(height: 8),
            _AskExpandableSongList(
              tracks: mix.tracks,
              isOffline: isOffline,
              onPlayTrack: (i) => ref
                  .read(playerStateProvider.notifier)
                  .playLocalPlaylist(
                    _entriesFromRefs(mix.tracks),
                    startIndex: i,
                  ),
              onRemoveTrack: !saved && mix.tracks.length > 1
                  ? (track) => unawaited(
                      ref
                          .read(askChatProvider.notifier)
                          .removeTrackFromAttachment(
                            message: widget.message,
                            attachmentIndex: widget.attachmentIndex,
                            videoId: track.videoId,
                          ),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
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
                OutlinedButton.icon(
                  onPressed: isOffline || mix.tracks.isEmpty
                      ? null
                      : () => _enqueueTracks(context, ref, mix.tracks),
                  icon: const Icon(LucideIcons.listEnd, size: 16),
                  label: Text(l10n.askActionQueue),
                ),
                if (saved) ...[
                  Chip(
                    avatar: Icon(
                      LucideIcons.check,
                      size: 16,
                      color: cs.primary,
                    ),
                    label: Text(l10n.askSavedStatus),
                  ),
                  TextButton.icon(
                    onPressed: () => _openSavedPlaylist(
                      context,
                      ref,
                      mix.savedPlaylistId!,
                      mix.title,
                    ),
                    icon: const Icon(LucideIcons.folderOpen, size: 16),
                    label: Text(l10n.askActionOpenPlaylist),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: _saving || mix.tracks.isEmpty
                        ? null
                        : () => _confirmSave(context),
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
    final chosenName = await showDialog<String>(
      context: context,
      builder: (_) => _SaveMixNameDialog(initialName: widget.mix.title),
    );
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

class _SaveMixNameDialog extends StatefulWidget {
  const _SaveMixNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_SaveMixNameDialog> createState() => _SaveMixNameDialogState();
}

class _SaveMixNameDialogState extends State<_SaveMixNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(l10n.askSaveDialogTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.askPlaylistNameLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.askActionConfirmSave),
        ),
      ],
    );
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
    final openablePlaylistId = p.savedPlaylistId ?? p.targetPlaylistId;

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
            const SizedBox(height: 8),
            _AskExpandableSongList(
              tracks: p.tracks,
              isOffline: isOffline,
              onPlayTrack: (i) => ref
                  .read(playerStateProvider.notifier)
                  .playLocalPlaylist(_entriesFromRefs(p.tracks), startIndex: i),
              onRemoveTrack: p.isPending && p.tracks.length > 1
                  ? (track) => unawaited(
                      ref
                          .read(askChatProvider.notifier)
                          .removeTrackFromAttachment(
                            message: widget.message,
                            attachmentIndex: widget.attachmentIndex,
                            videoId: track.videoId,
                          ),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            if (p.isPending)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy || p.tracks.isEmpty
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
                  if (p.tracks.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: isOffline
                          ? null
                          : () => _enqueueTracks(context, ref, p.tracks),
                      icon: const Icon(LucideIcons.listEnd, size: 16),
                      label: Text(l10n.askActionQueue),
                    ),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Icon(
                      p.status == 'saved' ? LucideIcons.check : LucideIcons.x,
                      size: 16,
                      color: p.status == 'saved'
                          ? cs.primary
                          : cs.onSurfaceVariant,
                    ),
                    label: Text(
                      p.status == 'saved'
                          ? l10n.askSavedStatus
                          : l10n.askDiscardedStatus,
                    ),
                  ),
                  if (p.status == 'saved' && openablePlaylistId != null)
                    TextButton.icon(
                      onPressed: () => _openSavedPlaylist(
                        context,
                        ref,
                        openablePlaylistId,
                        p.playlistName,
                      ),
                      icon: const Icon(LucideIcons.folderOpen, size: 16),
                      label: Text(l10n.askActionOpenPlaylist),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class AskTracksCard extends ConsumerWidget {
  const AskTracksCard({super.key, required this.attachment});

  final AskTracksAttachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isOffline = ref.watch(isOfflineProvider);
    final header = attachment.title.isNotEmpty
        ? attachment.title
        : l10n.askSectionTracks;

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
                Icon(LucideIcons.music, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    header,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  l10n.askTracksCount(attachment.tracks.length),
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _AskExpandableSongList(
              tracks: attachment.tracks,
              isOffline: isOffline,
              onPlayTrack: (i) => ref
                  .read(playerStateProvider.notifier)
                  .playLocalPlaylist(
                    _entriesFromRefs(attachment.tracks),
                    startIndex: i,
                  ),
            ),
            if (attachment.tracks.length > 1) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: isOffline
                        ? null
                        : () => ref
                              .read(playerStateProvider.notifier)
                              .playLocalPlaylist(
                                _entriesFromRefs(attachment.tracks),
                              ),
                    icon: const Icon(LucideIcons.play, size: 16),
                    label: Text(l10n.askActionPlay),
                  ),
                  OutlinedButton.icon(
                    onPressed: isOffline
                        ? null
                        : () => _enqueueTracks(context, ref, attachment.tracks),
                    icon: const Icon(LucideIcons.listEnd, size: 16),
                    label: Text(l10n.askActionQueue),
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

class AskArtistsCard extends StatelessWidget {
  const AskArtistsCard({
    super.key,
    required this.messageId,
    required this.attachmentIndex,
    required this.attachment,
  });

  final String messageId;
  final int attachmentIndex;
  final AskArtistsAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = attachment.title.isNotEmpty
        ? attachment.title
        : l10n.askSectionArtists;

    return _AskCarouselCard(
      icon: LucideIcons.user,
      title: title,
      height: 178,
      itemCount: attachment.artists.length,
      itemBuilder: (context, index) {
        final artist = attachment.artists[index];
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTap: () => ContextMenuSheet.showForArtist(
            context,
            artistId: artist.artistId,
            name: artist.name,
            thumbnailUrl: artist.thumbnailUrl,
            monthlyListeners: artist.monthlyListeners,
          ),
          child: ArtistCard(
            artistId: artist.artistId,
            name: artist.name,
            thumbnailUrl: artist.thumbnailUrl,
            monthlyListeners: artist.monthlyListeners,
            cardWidth: 124,
            heroTag:
                'ask_${messageId}_${attachmentIndex}_artist_${artist.artistId}_$index',
          ),
        );
      },
    );
  }
}

class AskAlbumsCard extends StatelessWidget {
  const AskAlbumsCard({
    super.key,
    required this.messageId,
    required this.attachmentIndex,
    required this.attachment,
  });

  final String messageId;
  final int attachmentIndex;
  final AskAlbumsAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = attachment.title.isNotEmpty
        ? attachment.title
        : l10n.askSectionAlbums;

    return _AskCarouselCard(
      icon: LucideIcons.disc3,
      title: title,
      height: 214,
      itemCount: attachment.albums.length,
      itemBuilder: (context, index) {
        final album = attachment.albums[index];
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTap: () => ContextMenuSheet.showForAlbum(
            context,
            albumId: album.albumId,
            name: album.name,
            artist: album.artist,
            artistId: album.artistId,
            thumbnailUrl: album.thumbnailUrl,
            year: album.year,
          ),
          child: AlbumCard(
            albumId: album.albumId,
            name: album.name,
            artist: album.artist,
            artistId: album.artistId,
            thumbnailUrl: album.thumbnailUrl,
            year: album.year,
            cardWidth: 144,
            heroTag:
                'ask_${messageId}_${attachmentIndex}_album_${album.albumId}_$index',
          ),
        );
      },
    );
  }
}

class AskPlaylistsCard extends ConsumerWidget {
  const AskPlaylistsCard({
    super.key,
    required this.messageId,
    required this.attachmentIndex,
    required this.attachment,
  });

  final String messageId;
  final int attachmentIndex;
  final AskPlaylistsAttachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final title = attachment.title.isNotEmpty
        ? attachment.title
        : l10n.askSectionPlaylists;

    return _AskCarouselCard(
      icon: LucideIcons.listMusic,
      title: title,
      height: 214,
      itemCount: attachment.playlists.length,
      itemBuilder: (context, index) {
        final pl = attachment.playlists[index];
        final tag =
            'ask_${messageId}_${attachmentIndex}_pl_${pl.localPlaylistId ?? pl.playlistId}_$index';
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onSecondaryTap: () {
            if (pl.isLocal) {
              ContextMenuSheet.showForCustomPlaylist(
                context,
                playlist: LocalPlaylistModel(
                  id: pl.localPlaylistId!,
                  name: pl.name,
                  description: pl.artist,
                  createdAt: DateTime.now(),
                ),
                onUpdated: () => ref.invalidate(playlistsProvider),
              );
            } else if (pl.playlistId != null) {
              ContextMenuSheet.showForPlaylist(
                context,
                playlistId: pl.playlistId!,
                name: pl.name,
                artist: pl.artist,
                thumbnailUrl: pl.thumbnailUrl,
              );
            }
          },
          child: PlaylistCard(
            playlistId: pl.playlistId,
            localPlaylistId: pl.localPlaylistId,
            name: pl.name,
            artist: pl.artist,
            thumbnailUrl: pl.thumbnailUrl,
            cardWidth: 144,
            heroTag: tag,
          ),
        );
      },
    );
  }
}

class AskPodcastsCard extends StatelessWidget {
  const AskPodcastsCard({super.key, required this.attachment});

  final AskPodcastsAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final header = attachment.title.isNotEmpty
        ? attachment.title
        : l10n.askSectionPodcasts;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.podcast, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    header,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final podcast in attachment.podcasts)
              PodcastTile(
                browseId: podcast.browseId,
                name: podcast.name,
                author: podcast.author,
                thumbnailUrl: podcast.thumbnailUrl,
                trailingActions: [
                  IconButton(
                    icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ContextMenuSheet.showForPodcast(
                      context,
                      browseId: podcast.browseId,
                      name: podcast.name,
                      author: podcast.author,
                      thumbnailUrl: podcast.thumbnailUrl,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class AskEpisodesCard extends StatelessWidget {
  const AskEpisodesCard({super.key, required this.attachment});

  final AskEpisodesAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final header = attachment.title.isNotEmpty
        ? attachment.title
        : l10n.askSectionEpisodes;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.mic, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    header,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final ep in attachment.episodes)
              EpisodeTile(
                videoId: ep.videoId,
                name: ep.name,
                podcastName: ep.podcastName,
                podcastBrowseId: ep.podcastBrowseId,
                thumbnailUrl: ep.thumbnailUrl,
                date: ep.date,
                trailingActions: [
                  IconButton(
                    icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ContextMenuSheet.showForEpisode(
                      context,
                      videoId: ep.videoId,
                      name: ep.name,
                      podcastName: ep.podcastName,
                      podcastBrowseId: ep.podcastBrowseId,
                      thumbnailUrl: ep.thumbnailUrl,
                      date: ep.date,
                      onGoToPodcast: (id) => context.push('/podcast/$id'),
                    ),
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

class _AskExpandableSongList extends ConsumerStatefulWidget {
  const _AskExpandableSongList({
    required this.tracks,
    required this.isOffline,
    required this.onPlayTrack,
    this.onRemoveTrack,
  });

  final List<AskTrackRef> tracks;
  final bool isOffline;
  final void Function(int index) onPlayTrack;
  final ValueChanged<AskTrackRef>? onRemoveTrack;

  @override
  ConsumerState<_AskExpandableSongList> createState() =>
      _AskExpandableSongListState();
}

class _AskExpandableSongListState
    extends ConsumerState<_AskExpandableSongList> {
  static const int _collapsedCount = 6;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tracks = widget.tracks;
    final visibleCount = _expanded
        ? tracks.length
        : tracks.length.clamp(0, _collapsedCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < visibleCount; i++)
          _buildTile(context, tracks[i], i),
        if (tracks.length > _collapsedCount)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                size: 16,
              ),
              label: Text(
                _expanded
                    ? l10n.askShowLessTracks
                    : l10n.askShowAllTracks(tracks.length),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTile(BuildContext context, AskTrackRef track, int index) {
    final l10n = AppLocalizations.of(context)!;
    return SongTile(
      videoId: track.videoId,
      title: track.title,
      artist: track.artist,
      thumbnailUrl: track.thumbnailUrl,
      duration: track.durationSec,
      isVideo: track.isVideo,
      albumName: track.albumName,
      artistId: track.artistId,
      albumId: track.albumId,
      artistsJson: track.artistsJson,
      isExplicit: track.isExplicit,
      onTap: () {
        if (widget.isOffline) {
          ref
              .read(actionFeedbackProvider.notifier)
              .report(l10n.askErrorOffline);
          return;
        }
        widget.onPlayTrack(index);
      },
      trailingActions: [
        if (widget.onRemoveTrack != null)
          IconButton(
            tooltip: l10n.askRemoveTrackFromCard,
            icon: Icon(
              LucideIcons.x,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: () => widget.onRemoveTrack!(track),
          ),
        IconButton(
          icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
          visualDensity: VisualDensity.compact,
          onPressed: () => ContextMenuSheet.showForSong(
            context,
            videoId: track.videoId,
            title: track.title,
            artist: track.artist,
            thumbnailUrl: track.thumbnailUrl,
            duration: track.durationSec,
            isVideo: track.isVideo,
            albumName: track.albumName,
            artistId: track.artistId,
            albumId: track.albumId,
            artistsJson: track.artistsJson,
            isExplicit: track.isExplicit,
          ),
        ),
      ],
    );
  }
}

class _AskCarouselCard extends StatefulWidget {
  const _AskCarouselCard({
    required this.icon,
    required this.title,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  final IconData icon;
  final String title;
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_AskCarouselCard> createState() => _AskCarouselCardState();
}

class _AskCarouselCardState extends State<_AskCarouselCard> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: widget.height,
              child: HoverCarouselArrows(
                controller: _controller,
                child: ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.itemCount,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: widget.itemBuilder,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

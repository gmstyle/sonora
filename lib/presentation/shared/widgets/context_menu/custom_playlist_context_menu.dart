import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../features/home/providers/home_provider.dart';
import '../../../features/library/providers/library_provider.dart';
import '../../../features/library/widgets/create_playlist_dialog.dart';
import '../../../features/library/widgets/linked_playlist_actions.dart';
import '../../../features/library/widgets/playlist_detail_view.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/play_local_playlist_use_case_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/spotify_sync_cooldown_provider.dart';
import '../detail_actions_bar.dart';
import '../thumbnail_widget.dart';
import 'action_tiles.dart';
import 'context_menu_presenter.dart';

class CustomPlaylistContextMenuSheet extends ConsumerWidget {
  final LocalPlaylistModel playlist;
  final VoidCallback onUpdated;
  final bool hideGoToPlaylist;
  final Set<String> omitActionIds;

  const CustomPlaylistContextMenuSheet({
    super.key,
    required this.playlist,
    required this.onUpdated,
    this.hideGoToPlaylist = false,
    this.omitActionIds = const {},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isOffline = ref.watch(isOfflineProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                ThumbnailWidget(
                  imageUrl: null,
                  size: 48,
                  shape: ThumbnailShape.rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        playlist.isLinked
                            ? linkedSourceLabel(l10n, playlist)
                            : 'Playlist',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showAction(omitActionIds, DetailActionId.play))
                    ActionTile(
                      icon: LucideIcons.play,
                      label: l10n.playAll,
                      onTap: () {
                        final player = ref.read(playerStateProvider.notifier);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        Navigator.pop(context);
                        _playAll(ref, playlist.id, player, feedback, l10n);
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.shuffle))
                    ActionTile(
                      icon: LucideIcons.shuffle,
                      label: l10n.shufflePlay,
                      onTap: () {
                        final player = ref.read(playerStateProvider.notifier);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        Navigator.pop(context);
                        _shufflePlay(ref, playlist.id, player, feedback, l10n);
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.queue))
                    ActionTile(
                      icon: LucideIcons.listMusic,
                      label: l10n.addToQueue,
                      onTap: () {
                        final player = ref.read(playerStateProvider.notifier);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        Navigator.pop(context);
                        _addToQueue(ref, playlist.id, player, feedback, l10n);
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.rename))
                    ActionTile(
                      icon: LucideIcons.pencil,
                      label: l10n.renamePlaylist,
                      onTap: () async {
                        final result = await showDialog<String>(
                          context: context,
                          builder: (_) => CreatePlaylistDialog(
                            initialName: playlist.name,
                            title: l10n.renamePlaylist,
                          ),
                        );
                        if (result != null &&
                            result.isNotEmpty &&
                            result != playlist.name) {
                          if (!context.mounted) return;
                          final notifier = ref.read(
                            libraryNotifierProvider.notifier,
                          );
                          Navigator.pop(context);
                          await notifier.updatePlaylist(
                            playlist.id,
                            name: result,
                          );
                          ref.invalidate(playlistsProvider);
                          onUpdated();
                        }
                      },
                    ),
                  if (playlist.isLinked) ...[
                    if (showAction(omitActionIds, DetailActionId.sync))
                      ActionTile(
                        icon: LucideIcons.refreshCw,
                        label: syncActionLabel(l10n, playlist),
                        enabled:
                            !isOffline && !isSpotifySyncCoolingDown(playlist),
                        onTap: () async {
                          final container = ProviderScope.containerOf(context);
                          final strings = l10n;
                          final dialogContext = Navigator.of(
                            context,
                            rootNavigator: true,
                          ).context;
                          if (isSpotifySyncCoolingDown(playlist)) {
                            ref
                                .read(actionFeedbackProvider.notifier)
                                .report(strings.playlistSyncSpotifyCooldown);
                            Navigator.pop(context);
                            return;
                          }
                          Navigator.pop(context);
                          if (!dialogContext.mounted) return;
                          await syncLinkedPlaylist(
                            dialogContext,
                            container,
                            strings,
                            playlist,
                          );
                        },
                      ),
                    if (showAction(omitActionIds, DetailActionId.unlink))
                      ActionTile(
                        icon: LucideIcons.unlink,
                        label: l10n.unlinkPlaylist,
                        onTap: () async {
                          final container = ProviderScope.containerOf(context);
                          final unlinked = await confirmAndUnlinkPlaylist(
                            container,
                            context,
                            playlist,
                          );
                          if (unlinked && context.mounted) {
                            Navigator.pop(context);
                            onUpdated();
                          }
                        },
                      ),
                  ],
                  ActionTile(
                    icon: LucideIcons.trash2,
                    label: l10n.deletePlaylist,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.deletePlaylist),
                          content: Text(
                            l10n.deletePlaylistConfirm(playlist.name),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l10n.cancel),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(l10n.delete),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        if (!context.mounted) return;
                        final notifier = ref.read(
                          libraryNotifierProvider.notifier,
                        );
                        // Detail page passes hideGoToPlaylist: leave after delete.
                        final leaveDetail = hideGoToPlaylist;
                        final nav = leaveDetail
                            ? Navigator.of(context, rootNavigator: true)
                            : null;
                        Navigator.pop(context);
                        await notifier.deletePlaylist(playlist.id);
                        ref.invalidate(playlistsProvider);
                        ref.invalidate(homeCombinedPlaylistsProvider);
                        ref.invalidate(homeRandomPlaylistsProvider);
                        onUpdated();
                        if (leaveDetail && nav != null && nav.canPop()) {
                          nav.pop();
                        }
                      }
                    },
                  ),
                  if (!hideGoToPlaylist)
                    ActionTile(
                      icon: LucideIcons.listVideo,
                      label: l10n.goToPlaylist,
                      onTap: () {
                        final nav = Navigator.of(context, rootNavigator: true);
                        Navigator.pop(context);
                        nav.push(
                          MaterialPageRoute(
                            builder: (_) => PlaylistDetailView(
                              playlist: playlist,
                              onUpdated: onUpdated,
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playAll(
    WidgetRef ref,
    int playlistId,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    feedback.report(l10n.playingPlaylist(playlist.name));
    try {
      final entries = await ref.read(
        playlistEntriesProvider(playlistId).future,
      );
      await player.playLocalPlaylist(entries, startIndex: 0);
    } catch (_) {}
  }

  Future<void> _shufflePlay(
    WidgetRef ref,
    int playlistId,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    feedback.report(l10n.shufflingPlaylist(playlist.name));
    try {
      final entries = await ref.read(
        playlistEntriesProvider(playlistId).future,
      );
      final shuffled = List<PlaylistEntryModel>.from(entries)..shuffle();
      await player.playLocalPlaylist(shuffled, startIndex: 0);
    } catch (_) {}
  }

  Future<void> _addToQueue(
    WidgetRef ref,
    int playlistId,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      final entries = await ref.read(
        playlistEntriesProvider(playlistId).future,
      );
      final items = await ref
          .read(playLocalPlaylistUseCaseProvider)
          .execute(entries, playIndex: -1);
      if (items.isNotEmpty) await player.addAllToQueue(items);
      feedback.report(l10n.addedToQueue(items.length));
    } catch (e) {
      debugPrint('Failed to add to queue: $e');
      feedback.report(l10n.failedToAddToQueue, kind: FeedbackKind.error);
    }
  }
}

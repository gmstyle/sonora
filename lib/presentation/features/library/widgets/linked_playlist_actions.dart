import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/library_models.dart';
import '../../../../domain/models/playlist_import.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/library_notifier.dart';
import '../../../providers/spotify_sync_cooldown_provider.dart';
import '../providers/library_provider.dart';
import 'sync_linked_playlist_dialog.dart';

String linkedSourceLabel(AppLocalizations l10n, LocalPlaylistModel playlist) {
  switch (playlist.sourceKind) {
    case 'spotify':
      return l10n.linkedToSpotify;
    case 'youtube':
      return l10n.linkedToYouTube;
    default:
      return l10n.linkedBadge;
  }
}

String syncActionLabel(AppLocalizations l10n, LocalPlaylistModel playlist) {
  switch (playlist.sourceKind) {
    case 'spotify':
      return l10n.syncFromSpotify;
    case 'youtube':
      return l10n.syncFromYouTube;
    default:
      return l10n.syncFromRemote;
  }
}

String formatPlaylistSyncResult(
  AppLocalizations l10n,
  PlaylistSyncResult result, {
  String? sourceKind,
}) {
  final trackChanged =
      result.added > 0 ||
      result.removed > 0 ||
      result.reordered ||
      result.skipped > 0;
  if (!trackChanged) {
    if (sourceKind == 'spotify') {
      return '${l10n.playlistSyncNoChanges}. ${l10n.playlistSyncSpotifyLagHint}';
    }
    return l10n.playlistSyncNoChanges;
  }
  final reorderPart = result.reordered ? l10n.playlistSyncReorderPart : '';
  final skipPart =
      result.skipped > 0 ? l10n.playlistSyncSkipPart(result.skipped) : '';
  return l10n.playlistSyncResult(
    result.added,
    result.removed,
    reorderPart,
    skipPart,
  );
}

/// Sync using a [ProviderContainer] that outlives dialogs/sheets (capture
/// before [Navigator.pop]). Prefer this over a sheet's [WidgetRef].
///
/// Shows a blocking [SyncLinkedPlaylistDialog] (identical for Spotify and
/// YouTube). Spotify-only: rejects when [isSpotifySyncCoolingDown].
Future<PlaylistSyncResult?> syncLinkedPlaylist(
  BuildContext context,
  ProviderContainer container,
  AppLocalizations l10n,
  LocalPlaylistModel playlist,
) async {
  final feedback = container.read(actionFeedbackProvider.notifier);

  if (isSpotifySyncCoolingDown(playlist)) {
    feedback.report(l10n.playlistSyncSpotifyCooldown);
    return null;
  }

  if (!context.mounted) return null;
  final result = await SyncLinkedPlaylistDialog.show(context, playlist);
  if (result == null) return null;

  container.invalidate(playlistsProvider);
  container.invalidate(playlistEntriesProvider(playlist.id));
  feedback.report(
    formatPlaylistSyncResult(l10n, result, sourceKind: playlist.sourceKind),
  );
  return result;
}

Future<bool> confirmAndUnlinkPlaylist(
  ProviderContainer container,
  BuildContext context,
  LocalPlaylistModel playlist,
) async {
  final l10n = AppLocalizations.of(context)!;
  final confirm = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(l10n.unlinkPlaylist),
          content: Text(l10n.unlinkPlaylistConfirm(playlist.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.unlinkPlaylist),
            ),
          ],
        ),
  );
  if (confirm != true) return false;
  await container
      .read(libraryNotifierProvider.notifier)
      .unlinkPlaylist(playlist.id);
  container.invalidate(playlistsProvider);
  container.read(actionFeedbackProvider.notifier).report(l10n.playlistUnlinked);
  return true;
}

/// Small chip shown next to linked playlist titles.
class LinkedPlaylistBadge extends StatelessWidget {
  final LocalPlaylistModel playlist;
  final bool compact;

  const LinkedPlaylistBadge({
    super.key,
    required this.playlist,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!playlist.isLinked) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final label =
        compact ? l10n.linkedBadge : linkedSourceLabel(l10n, playlist);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/playlist_card.dart';
import 'providers/user_provider.dart';

class UserPlaylistsScreen extends ConsumerWidget {
  final String channelId;
  final String params;
  final String? userName;

  const UserPlaylistsScreen({
    super.key,
    required this.channelId,
    required this.params,
    this.userName,
  });

  UserContentParams get _key => (channelId: channelId, params: params);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(userPlaylistsProvider(_key));
    final l10n = AppLocalizations.of(context)!;
    final title =
        userName != null && userName!.isNotEmpty
            ? '${l10n.playlists} · $userName'
            : l10n.playlists;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: playlistsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => ErrorRetryWidget(
              message: l10n.failedToLoadPlaylists,
              onRetry: () => ref.invalidate(userPlaylistsProvider(_key)),
            ),
        data: (playlists) {
          if (playlists.isEmpty) {
            return Center(child: Text(l10n.noContentAvailable));
          }

          final width = MediaQuery.of(context).size.width;
          final crossAxisCount =
              width < kCompactBreakpoint
                  ? 2
                  : width < kExpandedBreakpoint
                  ? 4
                  : 6;
          final cardWidth =
              (width - 32 - (crossAxisCount - 1) * 12) / crossAxisCount;

          return GridView.builder(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.62,
            ),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return PlaylistCard(
                playlistId: playlist.playlistId,
                name: playlist.name,
                artist: playlist.artist.name,
                thumbnailUrl:
                    playlist.thumbnails.isNotEmpty
                        ? playlist.thumbnails.last.url
                        : null,
                cardWidth: cardWidth,
                heroTag: 'user_playlist_all_${playlist.playlistId}',
              );
            },
          );
        },
      ),
    );
  }
}

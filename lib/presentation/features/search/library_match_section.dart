import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../shared/widgets/artist_tile.dart';
import '../../shared/widgets/context_menu_sheet.dart';
import '../../shared/widgets/song_tile.dart';
import '../../shared/widgets/thumbnail_widget.dart';
import '../library/providers/library_provider.dart';
import '../library/widgets/playlist_detail_view.dart';
import 'library_matches.dart';

/// Library hits for the search page.
///
/// [filter] follows the search chips: 0 shows every group, 1–5 show that
/// type. [cap] limits each group (the All view and the suggestion list).
/// [onSeeAll] receives the search filter index to open.
class LibraryMatchSection extends ConsumerWidget {
  final LibraryMatches matches;
  final int filter;
  final int? cap;
  final double inset;
  final ValueChanged<int>? onSeeAll;

  const LibraryMatchSection({
    super.key,
    required this.matches,
    required this.filter,
    required this.inset,
    this.cap,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (matches.isEmptyFor(filter)) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final children = <Widget>[
      _header(context, l10n.yourLibrary),
      if (filter == 0 || filter == 1)
        ..._songs(context, l10n, showGroupHeader: filter == 0),
      if (filter == 0 || filter == 2)
        ..._artists(context, l10n, showGroupHeader: filter == 0),
      if (filter == 0 || filter == 4) ...[
        ..._localPlaylists(context, ref, l10n, showGroupHeader: true),
        ..._likedPlaylists(context, l10n, showGroupHeader: true),
      ],
      if (filter == 0 || filter == 3)
        ..._albums(context, l10n, showGroupHeader: filter == 0),
      if (filter == 0 || filter == 5)
        ..._podcasts(context, l10n, showGroupHeader: filter == 0),
      if (filter == 0) ..._history(context, l10n),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  List<T> _take<T>(List<T> items) {
    if (cap == null || items.length <= cap!) return items;
    return items.take(cap!).toList();
  }

  bool _hasMore(int length) => cap != null && length > cap!;

  Widget _header(BuildContext context, String title, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 20, inset, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                AppLocalizations.of(context)!.showMore,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _songs(
    BuildContext context,
    AppLocalizations l10n, {
    required bool showGroupHeader,
  }) {
    if (matches.songs.isEmpty) return const [];
    final shown = _take(matches.songs);
    return [
      if (showGroupHeader)
        _header(
          context,
          l10n.favorites,
          onSeeAll: _hasMore(matches.songs.length) && onSeeAll != null
              ? () => onSeeAll!(1)
              : null,
        ),
      for (final song in shown)
        SongTile(
          videoId: song.videoId,
          title: song.title,
          artist: song.artist,
          artistsJson: song.artistsJson,
          thumbnailUrl: song.thumbnailUrl,
          duration: song.duration,
          artistId: song.artistId,
          albumId: song.albumId,
          isExplicit: song.isExplicit,
          isVideo: song.isVideo,
        ),
    ];
  }

  List<Widget> _artists(
    BuildContext context,
    AppLocalizations l10n, {
    required bool showGroupHeader,
  }) {
    if (matches.artists.isEmpty) return const [];
    final shown = _take(matches.artists);
    return [
      if (showGroupHeader)
        _header(
          context,
          l10n.artists,
          onSeeAll: _hasMore(matches.artists.length) && onSeeAll != null
              ? () => onSeeAll!(2)
              : null,
        ),
      for (final artist in shown)
        ArtistTile(
          artistId: artist.artistId,
          name: artist.name,
          thumbnailUrl: artist.thumbnailUrl,
        ),
    ];
  }

  List<Widget> _localPlaylists(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n, {
    required bool showGroupHeader,
  }) {
    if (matches.playlists.isEmpty) return const [];
    final shown = _take(matches.playlists);
    return [
      if (showGroupHeader)
        _header(
          context,
          l10n.myPlaylists,
          onSeeAll: _hasMore(matches.playlists.length) && onSeeAll != null
              ? () => onSeeAll!(4)
              : null,
        ),
      for (final playlist in shown)
        ListTile(
          leading: const Icon(LucideIcons.listVideo),
          title: Text(playlist.name),
          subtitle:
              playlist.description != null && playlist.description!.isNotEmpty
              ? Text(
                  playlist.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PlaylistDetailView(
                  playlist: playlist,
                  onUpdated: () => ref.invalidate(playlistsProvider),
                ),
              ),
            );
          },
          onLongPress: () => ContextMenuSheet.showForCustomPlaylist(
            context,
            playlist: playlist,
            onUpdated: () => ref.invalidate(playlistsProvider),
          ),
        ),
    ];
  }

  List<Widget> _likedPlaylists(
    BuildContext context,
    AppLocalizations l10n, {
    required bool showGroupHeader,
  }) {
    if (matches.likedPlaylists.isEmpty) return const [];
    final shown = _take(matches.likedPlaylists);
    return [
      if (showGroupHeader)
        _header(
          context,
          l10n.likedPlaylists,
          onSeeAll: _hasMore(matches.likedPlaylists.length) && onSeeAll != null
              ? () => onSeeAll!(4)
              : null,
        ),
      for (final playlist in shown)
        ListTile(
          leading: ThumbnailWidget(
            imageUrl: playlist.thumbnailUrl,
            size: 48,
            shape: ThumbnailShape.rounded,
          ),
          title: Text(playlist.name),
          subtitle: playlist.videoCount != null
              ? Text(l10n.videoCount(playlist.videoCount!))
              : null,
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => context.push('/playlist/${playlist.playlistId}'),
          onLongPress: () => ContextMenuSheet.showForPlaylist(
            context,
            playlistId: playlist.playlistId,
            name: playlist.name,
            thumbnailUrl: playlist.thumbnailUrl,
          ),
        ),
    ];
  }

  List<Widget> _albums(
    BuildContext context,
    AppLocalizations l10n, {
    required bool showGroupHeader,
  }) {
    if (matches.albums.isEmpty) return const [];
    final shown = _take(matches.albums);
    return [
      if (showGroupHeader)
        _header(
          context,
          l10n.albums,
          onSeeAll: _hasMore(matches.albums.length) && onSeeAll != null
              ? () => onSeeAll!(3)
              : null,
        ),
      for (final album in shown)
        ListTile(
          leading: ThumbnailWidget(
            imageUrl: album.thumbnailUrl,
            size: 48,
            shape: ThumbnailShape.rounded,
          ),
          title: Text(album.name),
          subtitle: Text(
            album.year != null
                ? l10n.albumInfo(album.artistName, '${album.year}')
                : album.artistName,
          ),
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => context.push('/album/${album.albumId}'),
          onLongPress: () => ContextMenuSheet.showForAlbum(
            context,
            albumId: album.albumId,
            name: album.name,
            artist: album.artistName,
            artistId: album.artistId,
            thumbnailUrl: album.thumbnailUrl,
            year: album.year,
          ),
        ),
    ];
  }

  List<Widget> _podcasts(
    BuildContext context,
    AppLocalizations l10n, {
    required bool showGroupHeader,
  }) {
    if (matches.podcasts.isEmpty) return const [];
    final shown = _take(matches.podcasts);
    return [
      if (showGroupHeader)
        _header(
          context,
          l10n.podcasts,
          onSeeAll: _hasMore(matches.podcasts.length) && onSeeAll != null
              ? () => onSeeAll!(5)
              : null,
        ),
      for (final podcast in shown)
        ListTile(
          leading: ThumbnailWidget(
            imageUrl: podcast.thumbnailUrl,
            size: 48,
            shape: ThumbnailShape.rounded,
          ),
          title: Text(podcast.name),
          subtitle: podcast.authorName != null
              ? Text(podcast.authorName!)
              : null,
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () => context.push('/podcast/${podcast.browseId}'),
          onLongPress: () => ContextMenuSheet.showForPodcast(
            context,
            browseId: podcast.browseId,
            name: podcast.name,
            author: podcast.authorName,
            thumbnailUrl: podcast.thumbnailUrl,
          ),
        ),
    ];
  }

  List<Widget> _history(BuildContext context, AppLocalizations l10n) {
    if (matches.history.isEmpty) return const [];
    final shown = _take(matches.history);
    return [
      _header(context, l10n.history),
      for (final entry in shown)
        SongTile(
          videoId: entry.videoId,
          title: entry.title,
          artist: entry.artist,
          thumbnailUrl: entry.thumbnailUrl,
          duration: entry.duration,
          isVideo: entry.isVideo,
          isExplicit: entry.isExplicit,
        ),
    ];
  }
}

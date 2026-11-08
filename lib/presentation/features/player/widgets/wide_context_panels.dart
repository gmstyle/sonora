import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/sonora_pulse_tokens.dart';
import '../../../../core/utils/artists_utils.dart';
import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/library_notifier.dart';
import '../../../shared/widgets/detail_affinity_button.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../album/providers/album_provider.dart';
import '../../artist/providers/artist_provider.dart';
import '../player_navigation.dart';
import 'related_view.dart';

/// Artist, album, and related shelves for the wide now-playing scroll.
///
/// Artist and album share the left column. Related is the right column.
/// On wide the two columns share [columnHeight] and each scrolls its overflow.
class WideContextPanels extends ConsumerWidget {
  const WideContextPanels({
    super.key,
    required this.videoId,
    required this.artistId,
    required this.albumId,
    required this.showRelated,
    this.stacked = false,
    this.columnHeight,
    this.pageScroll,
  });

  final String videoId;
  final String? artistId;
  final String? albumId;
  final bool showRelated;

  /// Artist, album, and related in one column. Tablet uses this.
  final bool stacked;

  /// Shared height of the side-by-side columns. Null keeps them content-sized.
  final double? columnHeight;

  /// Page scroll that receives a column's leftover drag, so the disc returns.
  final ScrollController? pageScroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artist = artistId != null && artistId!.isNotEmpty;
    final album = albumId != null && albumId!.isNotEmpty;
    final infoChildren = <Widget>[
      if (artist) _ArtistPanel(artistId: artistId!),
      if (album) _AlbumPanel(albumId: albumId!),
    ];
    final info = infoChildren.isEmpty
        ? null
        : Column(
            children: [
              for (var i = 0; i < infoChildren.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                infoChildren[i],
              ],
            ],
          );
    final related = showRelated
        ? PlayerSurfaceCard(
            child: RelatedView(videoId: videoId, embedded: true),
          )
        : null;
    if (info == null && related == null) return const SizedBox.shrink();

    final height = columnHeight;
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide =
            !stacked &&
            info != null &&
            related != null &&
            height != null &&
            height > 0 &&
            constraints.maxWidth >= 720;
        if (sideBySide) {
          return SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _ColumnScroll(outer: pageScroll, child: info),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ColumnScroll(outer: pageScroll, child: related),
                  ),
                ],
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 8),
          child: Column(
            children: [
              ?info,
              if (info != null && related != null) const SizedBox(height: 16),
              ?related,
            ],
          ),
        );
      },
    );
  }
}

/// One now-playing column. Extra content scrolls here.
///
/// A drag past either edge moves [outer], so the disc above can come back
/// and a short column still scrolls the page.
class _ColumnScroll extends StatefulWidget {
  const _ColumnScroll({required this.child, this.outer});

  final Widget child;
  final ScrollController? outer;

  @override
  State<_ColumnScroll> createState() => _ColumnScrollState();
}

class _ColumnScrollState extends State<_ColumnScroll> {
  final ScrollController _controller = ScrollController();
  bool _handingOff = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onOverscroll(OverscrollNotification notification) {
    if (_handingOff || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final outer = widget.outer;
    if (outer == null || !outer.hasClients || notification.overscroll == 0) {
      return false;
    }
    final position = outer.position;
    final target = (position.pixels + notification.overscroll).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return true;
    _handingOff = true;
    position.jumpTo(target);
    _handingOff = false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<OverscrollNotification>(
      onNotification: _onOverscroll,
      child: Scrollbar(
        controller: _controller,
        child: SingleChildScrollView(
          controller: _controller,
          primary: false,
          physics: const ClampingScrollPhysics(),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Player card surface shared by context shelves and the right-hand panels.
///
/// `surfaceContainer`, media radius, clipped. Inner padding defaults to 16.
/// Side panels pass [EdgeInsets.zero] because their lists pad themselves.
class PlayerSurfaceCard extends StatelessWidget {
  const PlayerSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(SonoraPulseTokens.radiusMedia),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _ArtistPanel extends ConsumerWidget {
  const _ArtistPanel({required this.artistId});

  final String artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistProvider(artistId));
    final l10n = AppLocalizations.of(context)!;
    return PlayerSurfaceCard(
      child: artistAsync.when(
        loading: () => const ShimmerLoading(variant: ShimmerVariant.tile),
        error: (error, _) => _Retry(
          message: l10n.failedToLoadArtist,
          onRetry: () => ref.invalidate(artistProvider(artistId)),
        ),
        data: (artist) => _ArtistBody(artist: artist),
      ),
    );
  }
}

class _ArtistBody extends ConsumerWidget {
  const _ArtistBody({required this.artist});

  final ArtistFull artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final thumb = artist.thumbnails.isNotEmpty
        ? artist.thumbnails.last.url
        : null;
    final stats = [
      if (artist.monthlyListeners != null &&
          artist.monthlyListeners!.isNotEmpty)
        artist.monthlyListeners!,
      if (artist.subscriberCount != null && artist.subscriberCount!.isNotEmpty)
        '${artist.subscriberCount} ${l10n.subscribers}',
    ].join(' · ');
    final followed = ref.watch(followedArtistProvider(artist.artistId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cover(
          url: thumb,
          height: 180,
          onTap: () =>
              closeFullPlayerAndNavigate(context, '/artist/${artist.artistId}'),
        ),
        const SizedBox(height: 12),
        Text(l10n.aboutTheArtist, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        InkWell(
          onTap: () =>
              closeFullPlayerAndNavigate(context, '/artist/${artist.artistId}'),
          child: Text(
            artist.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(stats, style: theme.textTheme.bodySmall),
        ],
        if (artist.description != null && artist.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            artist.description!,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: followed.when(
            loading: () => DetailAffinityButton(
              iconOnly: false,
              isActive: false,
              enabled: false,
              idleIcon: DetailAffinityButton.followIdle,
              activeIcon: DetailAffinityButton.followActive,
              idleLabel: l10n.follow,
              activeLabel: l10n.following,
              activeColor: DetailAffinityButton.brandColor(theme.colorScheme),
              onPressed: null,
            ),
            error: (error, _) => const SizedBox.shrink(),
            data: (row) => DetailAffinityButton(
              iconOnly: false,
              isActive: row != null,
              idleIcon: DetailAffinityButton.followIdle,
              activeIcon: DetailAffinityButton.followActive,
              idleLabel: l10n.follow,
              activeLabel: l10n.following,
              activeColor: DetailAffinityButton.brandColor(theme.colorScheme),
              onPressed: () {
                ref
                    .read(libraryNotifierProvider.notifier)
                    .toggleFollowedArtist(
                      FollowedArtistModel(
                        artistId: artist.artistId,
                        name: artist.name,
                        thumbnailUrl: thumb,
                        addedAt: DateTime.now(),
                      ),
                    );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumPanel extends ConsumerWidget {
  const _AlbumPanel({required this.albumId});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumAsync = ref.watch(albumProvider(albumId));
    final l10n = AppLocalizations.of(context)!;
    return PlayerSurfaceCard(
      child: albumAsync.when(
        loading: () => const ShimmerLoading(variant: ShimmerVariant.tile),
        error: (error, _) => _Retry(
          message: l10n.failedToLoadAlbum,
          onRetry: () => ref.invalidate(albumProvider(albumId)),
        ),
        data: (album) => _AlbumBody(album: album),
      ),
    );
  }
}

class _AlbumBody extends ConsumerWidget {
  const _AlbumBody({required this.album});

  final AlbumFull album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final thumb = album.thumbnails.isNotEmpty
        ? album.thumbnails.last.url
        : null;
    final meta = [
      if (album.year != null) '${album.year}',
      if (album.songs.isNotEmpty) '${album.songs.length} ${l10n.songs}',
    ].join(' · ');
    final liked = ref.watch(likedAlbumProvider(album.albumId));
    final artistName = displayArtists(album.artists);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cover(
          url: thumb,
          height: 180,
          onTap: () =>
              closeFullPlayerAndNavigate(context, '/album/${album.albumId}'),
        ),
        const SizedBox(height: 12),
        Text(l10n.fromTheAlbum, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        InkWell(
          onTap: () =>
              closeFullPlayerAndNavigate(context, '/album/${album.albumId}'),
          child: Text(
            album.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (artistName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(artistName, style: theme.textTheme.bodyMedium),
        ],
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(meta, style: theme.textTheme.bodySmall),
        ],
        if (album.description != null && album.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            album.description!,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: liked.when(
            loading: () => DetailAffinityButton(
              iconOnly: false,
              isActive: false,
              enabled: false,
              idleIcon: DetailAffinityButton.likeIdle,
              activeIcon: DetailAffinityButton.likeActive,
              idleLabel: l10n.like,
              activeLabel: l10n.liked,
              activeColor: DetailAffinityButton.likeColor(theme.colorScheme),
              onPressed: null,
            ),
            error: (error, _) => const SizedBox.shrink(),
            data: (row) => DetailAffinityButton(
              iconOnly: false,
              isActive: row != null,
              idleIcon: DetailAffinityButton.likeIdle,
              activeIcon: DetailAffinityButton.likeActive,
              idleLabel: l10n.like,
              activeLabel: l10n.liked,
              activeColor: DetailAffinityButton.likeColor(theme.colorScheme),
              onPressed: () {
                ref
                    .read(libraryNotifierProvider.notifier)
                    .toggleLikedAlbum(
                      LikedAlbumModel(
                        albumId: album.albumId,
                        name: album.name,
                        artistName: artistName,
                        artistId: album.artists.isNotEmpty
                            ? album.artists.first.artistId
                            : null,
                        thumbnailUrl: thumb,
                        year: album.year,
                        addedAt: DateTime.now(),
                      ),
                    );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.height, required this.onTap});

  final String? url;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: url == null
              ? ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(
                    LucideIcons.disc3,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              : CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(onPressed: onRetry, child: Text(message)),
    );
  }
}

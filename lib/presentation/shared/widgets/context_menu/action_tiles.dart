import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/library_notifier.dart';
import '../detail_affinity_button.dart';

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: enabled ? onTap : null,
      enabled: enabled,
      dense: true,
    );
  }
}

class LoadingTile extends StatelessWidget {
  final IconData icon;
  final String label;

  const LoadingTile({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final baseColor = cs.surfaceContainerHighest;
    final highlightColor = cs.surfaceContainerLow;
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: ColoredBox(color: cs.onSurface.withAlpha(40)),
        ),
        title: SizedBox(
          height: 14,
          child: ColoredBox(color: cs.onSurface.withAlpha(30)),
        ),
        enabled: false,
        dense: true,
      ),
    );
  }
}

class LikeActionTile extends ConsumerWidget {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final String? artistId;
  final String? albumId;
  final String? artistsJson;
  final bool isVideo;
  final bool isExplicit;
  final int? duration;
  final bool isPlayable;

  const LikeActionTile({
    super.key,
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.artistId,
    this.albumId,
    this.artistsJson,
    this.isVideo = false,
    this.isExplicit = false,
    this.duration,
    this.isPlayable = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedSongProvider(videoId));
    return likedAsync.when(
      loading: () => isPlayable
          ? ListTile(
              leading: const Icon(DetailAffinityButton.likeIdle),
              title: Text(AppLocalizations.of(context)!.like),
              enabled: false,
              dense: true,
            )
          : const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        // Unplayable tracks cannot be newly liked; keep unlike for rows
        // already saved before this gate existed.
        if (!isPlayable && !isLiked) return const SizedBox.shrink();
        return ListTile(
          leading: Icon(
            isLiked
                ? DetailAffinityButton.likeActive
                : DetailAffinityButton.likeIdle,
            color: DetailAffinityButton.glyphColor(
              Theme.of(context).colorScheme,
              isActive: isLiked,
              activeColor: DetailAffinityButton.likeColor(
                Theme.of(context).colorScheme,
              ),
            ),
          ),
          title: Text(
            isLiked
                ? AppLocalizations.of(context)!.unlike
                : AppLocalizations.of(context)!.like,
          ),
          onTap: () async {
            await ref
                .read(libraryNotifierProvider.notifier)
                .toggleLikedSong(
                  LikedSongModel(
                    videoId: videoId,
                    title: title,
                    artist: artist,
                    thumbnailUrl: thumbnailUrl,
                    artistId: artistId,
                    albumId: albumId,
                    artistsJson: artistsJson,
                    addedAt: DateTime.now(),
                    isVideo: isVideo,
                    isExplicit: isExplicit,
                    duration: duration,
                  ),
                );
          },
          dense: true,
        );
      },
    );
  }
}

class FollowArtistActionTile extends ConsumerWidget {
  final String artistId;
  final String name;
  final String? thumbnailUrl;

  const FollowArtistActionTile({
    super.key,
    required this.artistId,
    required this.name,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followedAsync = ref.watch(followedArtistProvider(artistId));
    return followedAsync.when(
      loading: () => ListTile(
        leading: Icon(LucideIcons.userPlus),
        title: Text(AppLocalizations.of(context)!.follow),
        enabled: false,
        dense: true,
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (followed) {
        final isFollowing = followed != null;
        return ListTile(
          leading: Icon(
            isFollowing
                ? DetailAffinityButton.followActive
                : DetailAffinityButton.followIdle,
            color: DetailAffinityButton.glyphColor(
              Theme.of(context).colorScheme,
              isActive: isFollowing,
              activeColor: DetailAffinityButton.brandColor(
                Theme.of(context).colorScheme,
              ),
            ),
          ),
          title: Text(
            isFollowing
                ? AppLocalizations.of(context)!.following
                : AppLocalizations.of(context)!.follow,
          ),
          onTap: () async {
            await ref
                .read(libraryNotifierProvider.notifier)
                .toggleFollowedArtist(
                  FollowedArtistModel(
                    artistId: artistId,
                    name: name,
                    thumbnailUrl: thumbnailUrl,
                    addedAt: DateTime.now(),
                  ),
                );
          },
          dense: true,
        );
      },
    );
  }
}

class LikeAlbumActionTile extends ConsumerWidget {
  final String albumId;
  final String name;
  final String artistName;
  final String? artistId;
  final String? thumbnailUrl;
  final int? year;

  const LikeAlbumActionTile({
    super.key,
    required this.albumId,
    required this.name,
    required this.artistName,
    this.artistId,
    this.thumbnailUrl,
    this.year,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedAlbumProvider(albumId));
    return likedAsync.when(
      loading: () => ListTile(
        leading: const Icon(DetailAffinityButton.likeIdle),
        title: Text(AppLocalizations.of(context)!.like),
        enabled: false,
        dense: true,
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        return ListTile(
          leading: Icon(
            isLiked
                ? DetailAffinityButton.likeActive
                : DetailAffinityButton.likeIdle,
            color: DetailAffinityButton.glyphColor(
              Theme.of(context).colorScheme,
              isActive: isLiked,
              activeColor: DetailAffinityButton.likeColor(
                Theme.of(context).colorScheme,
              ),
            ),
          ),
          title: Text(
            isLiked
                ? AppLocalizations.of(context)!.unlike
                : AppLocalizations.of(context)!.like,
          ),
          onTap: () async {
            await ref
                .read(libraryNotifierProvider.notifier)
                .toggleLikedAlbum(
                  LikedAlbumModel(
                    albumId: albumId,
                    name: name,
                    artistName: artistName,
                    artistId: artistId,
                    thumbnailUrl: thumbnailUrl,
                    year: year,
                    addedAt: DateTime.now(),
                  ),
                );
          },
          dense: true,
        );
      },
    );
  }
}

class LikePlaylistActionTile extends ConsumerWidget {
  final String playlistId;
  final String name;
  final String? thumbnailUrl;

  const LikePlaylistActionTile({
    super.key,
    required this.playlistId,
    required this.name,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedAsync = ref.watch(likedPlaylistProvider(playlistId));
    return likedAsync.when(
      loading: () => ListTile(
        leading: const Icon(DetailAffinityButton.likeIdle),
        title: Text(AppLocalizations.of(context)!.like),
        enabled: false,
        dense: true,
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        return ListTile(
          leading: Icon(
            isLiked
                ? DetailAffinityButton.likeActive
                : DetailAffinityButton.likeIdle,
            color: DetailAffinityButton.glyphColor(
              Theme.of(context).colorScheme,
              isActive: isLiked,
              activeColor: DetailAffinityButton.likeColor(
                Theme.of(context).colorScheme,
              ),
            ),
          ),
          title: Text(
            isLiked
                ? AppLocalizations.of(context)!.unlike
                : AppLocalizations.of(context)!.like,
          ),
          onTap: () async {
            await ref
                .read(libraryNotifierProvider.notifier)
                .toggleLikedPlaylist(
                  LikedPlaylistModel(
                    playlistId: playlistId,
                    name: name,
                    thumbnailUrl: thumbnailUrl,
                    addedAt: DateTime.now(),
                  ),
                );
          },
          dense: true,
        );
      },
    );
  }
}

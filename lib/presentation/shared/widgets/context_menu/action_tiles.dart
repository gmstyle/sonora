import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../features/tv/tv_metrics.dart';
import '../../../features/tv/widgets/tv_focusable.dart';
import '../../../providers/android_tv_provider.dart';
import '../../../providers/library_notifier.dart';
import '../detail_affinity_button.dart';

/// Shared pill row used by context menu tiles when rendered on Android TV.
class TvContextMenuTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  const TvContextMenuTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.label,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = enabled
        ? TvColors.textPrimary
        : TvColors.textSecondary.withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: TvFocusable(
        onSelect: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: enabled ? 0.06 : 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TvColors.borderFaint),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: enabled ? (iconColor ?? TvColors.textSecondary) : fg,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActionTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isAndroidTvProvider)) {
      return TvContextMenuTile(
        icon: icon,
        label: label,
        onTap: onTap,
        enabled: enabled,
      );
    }
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
    final isTv = ref.watch(isAndroidTvProvider);
    final likedAsync = ref.watch(likedSongProvider(videoId));
    return likedAsync.when(
      loading: () => isPlayable
          ? (isTv
                ? TvContextMenuTile(
                    icon: DetailAffinityButton.likeIdle,
                    label: AppLocalizations.of(context)!.like,
                    enabled: false,
                  )
                : ListTile(
                    leading: const Icon(DetailAffinityButton.likeIdle),
                    title: Text(AppLocalizations.of(context)!.like),
                    enabled: false,
                    dense: true,
                  ))
          : const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        // Unplayable tracks cannot be newly liked; keep unlike for rows
        // already saved before this gate existed.
        if (!isPlayable && !isLiked) return const SizedBox.shrink();
        final icon = isLiked
            ? DetailAffinityButton.likeActive
            : DetailAffinityButton.likeIdle;
        final color = DetailAffinityButton.glyphColor(
          Theme.of(context).colorScheme,
          isActive: isLiked,
          activeColor: DetailAffinityButton.likeColor(
            Theme.of(context).colorScheme,
          ),
        );
        final label = isLiked
            ? AppLocalizations.of(context)!.unlike
            : AppLocalizations.of(context)!.like;
        void toggle() {
          ref
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
        }

        if (isTv) {
          return TvContextMenuTile(
            icon: icon,
            iconColor: color,
            label: label,
            onTap: toggle,
          );
        }
        return ListTile(
          leading: Icon(icon, color: color),
          title: Text(label),
          onTap: toggle,
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
    final isTv = ref.watch(isAndroidTvProvider);
    final followedAsync = ref.watch(followedArtistProvider(artistId));
    return followedAsync.when(
      loading: () => isTv
          ? TvContextMenuTile(
              icon: LucideIcons.userPlus,
              label: AppLocalizations.of(context)!.follow,
              enabled: false,
            )
          : ListTile(
              leading: Icon(LucideIcons.userPlus),
              title: Text(AppLocalizations.of(context)!.follow),
              enabled: false,
              dense: true,
            ),
      error: (e, _) => const SizedBox.shrink(),
      data: (followed) {
        final isFollowing = followed != null;
        final icon = isFollowing
            ? DetailAffinityButton.followActive
            : DetailAffinityButton.followIdle;
        final color = DetailAffinityButton.glyphColor(
          Theme.of(context).colorScheme,
          isActive: isFollowing,
          activeColor: DetailAffinityButton.brandColor(
            Theme.of(context).colorScheme,
          ),
        );
        final label = isFollowing
            ? AppLocalizations.of(context)!.following
            : AppLocalizations.of(context)!.follow;
        void toggle() {
          ref
              .read(libraryNotifierProvider.notifier)
              .toggleFollowedArtist(
                FollowedArtistModel(
                  artistId: artistId,
                  name: name,
                  thumbnailUrl: thumbnailUrl,
                  addedAt: DateTime.now(),
                ),
              );
        }

        if (isTv) {
          return TvContextMenuTile(
            icon: icon,
            iconColor: color,
            label: label,
            onTap: toggle,
          );
        }
        return ListTile(
          leading: Icon(icon, color: color),
          title: Text(label),
          onTap: toggle,
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
    final isTv = ref.watch(isAndroidTvProvider);
    final likedAsync = ref.watch(likedAlbumProvider(albumId));
    return likedAsync.when(
      loading: () => isTv
          ? TvContextMenuTile(
              icon: DetailAffinityButton.likeIdle,
              label: AppLocalizations.of(context)!.like,
              enabled: false,
            )
          : ListTile(
              leading: const Icon(DetailAffinityButton.likeIdle),
              title: Text(AppLocalizations.of(context)!.like),
              enabled: false,
              dense: true,
            ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        final icon = isLiked
            ? DetailAffinityButton.likeActive
            : DetailAffinityButton.likeIdle;
        final color = DetailAffinityButton.glyphColor(
          Theme.of(context).colorScheme,
          isActive: isLiked,
          activeColor: DetailAffinityButton.likeColor(
            Theme.of(context).colorScheme,
          ),
        );
        final label = isLiked
            ? AppLocalizations.of(context)!.unlike
            : AppLocalizations.of(context)!.like;
        void toggle() {
          ref
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
        }

        if (isTv) {
          return TvContextMenuTile(
            icon: icon,
            iconColor: color,
            label: label,
            onTap: toggle,
          );
        }
        return ListTile(
          leading: Icon(icon, color: color),
          title: Text(label),
          onTap: toggle,
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
    final isTv = ref.watch(isAndroidTvProvider);
    final likedAsync = ref.watch(likedPlaylistProvider(playlistId));
    return likedAsync.when(
      loading: () => isTv
          ? TvContextMenuTile(
              icon: DetailAffinityButton.likeIdle,
              label: AppLocalizations.of(context)!.like,
              enabled: false,
            )
          : ListTile(
              leading: const Icon(DetailAffinityButton.likeIdle),
              title: Text(AppLocalizations.of(context)!.like),
              enabled: false,
              dense: true,
            ),
      error: (e, _) => const SizedBox.shrink(),
      data: (liked) {
        final isLiked = liked != null;
        final icon = isLiked
            ? DetailAffinityButton.likeActive
            : DetailAffinityButton.likeIdle;
        final color = DetailAffinityButton.glyphColor(
          Theme.of(context).colorScheme,
          isActive: isLiked,
          activeColor: DetailAffinityButton.likeColor(
            Theme.of(context).colorScheme,
          ),
        );
        final label = isLiked
            ? AppLocalizations.of(context)!.unlike
            : AppLocalizations.of(context)!.like;
        void toggle() {
          ref
              .read(libraryNotifierProvider.notifier)
              .toggleLikedPlaylist(
                LikedPlaylistModel(
                  playlistId: playlistId,
                  name: name,
                  thumbnailUrl: thumbnailUrl,
                  addedAt: DateTime.now(),
                ),
              );
        }

        if (isTv) {
          return TvContextMenuTile(
            icon: icon,
            iconColor: color,
            label: label,
            onTap: toggle,
          );
        }
        return ListTile(
          leading: Icon(icon, color: color),
          title: Text(label),
          onTap: toggle,
          dense: true,
        );
      },
    );
  }
}

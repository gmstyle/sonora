import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/queue_track.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../shared/widgets/thumbnail_widget.dart';
import '../../shared/widgets/vinyl_artwork.dart';
import '../album/providers/album_provider.dart';
import '../artist/providers/artist_provider.dart';
import 'full_player_content.dart';

/// Now-playing chrome that lives with vertical navigation.
///
/// Compact (tablet rail / collapsed sidebar): progress-ring disc.
/// Expanded (wide sidebar): identity row plus catalog context (album, artist,
/// or podcast). Transport and seek always live in the mini player, never here.
class NavNowPlaying extends ConsumerWidget {
  final bool expanded;

  const NavNowPlaying({super.key, required this.expanded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final currentSong = playerState.currentSong;
    if (currentSong == null) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.bottomCenter,
      child:
          expanded
              ? _ExpandedCard(playerState: playerState)
              : _CompactDisc(playerState: playerState),
    );
  }
}

class _CompactDisc extends ConsumerWidget {
  final PlayerState playerState;

  const _CompactDisc({required this.playerState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = playerState.currentSong!;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final totalMs = playerState.duration.inMilliseconds;
    final progress =
        totalMs > 0 ? playerState.position.inMilliseconds / totalMs : 0.0;
    final tooltip = '${song.title} — ${song.artist ?? l10n.unknownArtist}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: () => openFullPlayer(context),
          child: CustomPaint(
            painter: _ProgressRingPainter(
              progress: progress.clamp(0.0, 1.0),
              trackColor: cs.outlineVariant.withValues(alpha: 0.45),
              progressColor: cs.primary,
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: _Artwork(
                imageUrl: song.artUri?.toString(),
                size: 44,
                isPlaying: playerState.isPlaying,
                compact: true,
                isEpisode: QueueTrack.fromMediaItem(song).isEpisode,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedCard extends ConsumerWidget {
  final PlayerState playerState;

  const _ExpandedCard({required this.playerState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = playerState.currentSong!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final track = QueueTrack.fromMediaItem(song);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Material(
        color: cs.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: l10n.openPlayer,
              child: InkWell(
                onTap: () => openFullPlayer(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Row(
                    children: [
                      _Artwork(
                        imageUrl: song.artUri?.toString(),
                        size: 56,
                        isPlaying: playerState.isPlaying,
                        compact: false,
                        isEpisode: track.isEpisode,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist ?? l10n.unknownArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _CatalogContext(track: track),
          ],
        ),
      ),
    );
  }
}

class _CatalogContext extends ConsumerWidget {
  final QueueTrack track;

  const _CatalogContext({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (track.isEpisode) {
      return _PodcastContext(track: track);
    }
    final albumId = track.albumId;
    if (albumId != null && albumId.isNotEmpty) {
      return _AlbumContext(track: track, albumId: albumId);
    }
    final artistId = track.artistId;
    if (artistId != null && artistId.isNotEmpty) {
      return _ArtistContext(artistId: artistId);
    }
    return const SizedBox.shrink();
  }
}

class _PodcastContext extends StatelessWidget {
  final QueueTrack track;

  const _PodcastContext({required this.track});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name =
        (track.artist != null && track.artist!.isNotEmpty)
            ? track.artist!
            : null;
    if (name == null) return const SizedBox.shrink();

    final browseId = track.podcastBrowseId;
    return _CatalogTile(
      thumbnailUrl: track.artUri?.toString(),
      circularThumb: false,
      label: l10n.fromThePodcast,
      title: name,
      subtitle: track.publishDate,
      onTap:
          browseId == null || browseId.isEmpty
              ? null
              : () => context.push('/podcast/$browseId'),
    );
  }
}

class _AlbumContext extends ConsumerWidget {
  final QueueTrack track;
  final String albumId;

  const _AlbumContext({required this.track, required this.albumId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumAsync = ref.watch(albumProvider(albumId));
    return albumAsync.maybeWhen(
      data: (album) {
        final l10n = AppLocalizations.of(context)!;
        final thumb =
            album.thumbnails.isNotEmpty ? album.thumbnails.last.url : null;
        final index = album.songs.indexWhere((s) => s.videoId == track.videoId);
        final parts = <String>[
          if (album.year != null) '${album.year}',
          if (album.songs.isNotEmpty) l10n.catalogSongCount(album.songs.length),
          if (index >= 0) '${index + 1} / ${album.songs.length}',
        ];
        return _CatalogTile(
          thumbnailUrl: thumb,
          circularThumb: false,
          label: l10n.fromTheAlbum,
          title: album.name,
          subtitle: parts.isEmpty ? null : parts.join(' · '),
          onTap: () => context.push('/album/$albumId'),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ArtistContext extends ConsumerWidget {
  final String artistId;

  const _ArtistContext({required this.artistId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistProvider(artistId));
    return artistAsync.maybeWhen(
      data: (artist) {
        final l10n = AppLocalizations.of(context)!;
        final thumb =
            artist.thumbnails.isNotEmpty ? artist.thumbnails.last.url : null;
        final stats = <String>[
          if (artist.subscriberCount != null &&
              artist.subscriberCount!.isNotEmpty)
            '${artist.subscriberCount} ${l10n.subscribers}',
          if (artist.monthlyListeners != null &&
              artist.monthlyListeners!.isNotEmpty)
            artist.monthlyListeners!,
        ];
        final bio = artist.description?.trim();
        return _CatalogTile(
          thumbnailUrl: thumb,
          circularThumb: true,
          label: l10n.aboutTheArtist,
          title: stats.isNotEmpty ? stats.join(' · ') : artist.name,
          subtitle: (bio != null && bio.isNotEmpty) ? bio : null,
          subtitleMaxLines: 2,
          onTap: () => context.push('/artist/$artistId'),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  final String? thumbnailUrl;
  final bool circularThumb;
  final String label;
  final String title;
  final String? subtitle;
  final int subtitleMaxLines;
  final VoidCallback? onTap;

  const _CatalogTile({
    required this.thumbnailUrl,
    required this.circularThumb,
    required this.label,
    required this.title,
    this.subtitle,
    this.subtitleMaxLines = 1,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.35)),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ThumbnailWidget(
                  imageUrl: thumbnailUrl,
                  size: 40,
                  shape:
                      circularThumb
                          ? ThumbnailShape.circle
                          : ThumbnailShape.rounded,
                  borderRadius: circularThumb ? null : 8,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: subtitleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Artwork extends ConsumerWidget {
  final String? imageUrl;
  final double size;
  final bool isPlaying;
  final bool compact;
  final bool isEpisode;

  const _Artwork({
    required this.imageUrl,
    required this.size,
    required this.isPlaying,
    required this.compact,
    this.isEpisode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useVinyl =
        ref.watch(settingsProvider.select((s) => s.useVinylStyle)) &&
        !isEpisode;
    if (useVinyl) {
      return VinylArtwork(
        imageUrl: imageUrl,
        size: size,
        isPlaying: isPlaying,
        useShadow: false,
      );
    }
    return ThumbnailWidget(
      imageUrl: imageUrl,
      size: size,
      shape: compact ? ThumbnailShape.circle : ThumbnailShape.rounded,
      borderRadius: compact ? null : 8,
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.5;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        trackColor != oldDelegate.trackColor ||
        progressColor != oldDelegate.progressColor;
  }
}

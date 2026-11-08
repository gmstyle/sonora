import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/queue_track.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/player_provider.dart';
import '../../shared/widgets/context_menu_sheet.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/vinyl_artwork.dart';
import '../../shared/widgets/video_badge.dart';
import '../../shared/widgets/explicit_badge.dart';
import '../../providers/settings_provider.dart';
import '../../../core/utils/layout_breakpoints.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/sonora_pulse_tokens.dart';
import 'player_sheet_mobile.dart';
import 'widgets/animated_play_pause_icon.dart';
import 'widgets/cast_button.dart';
import 'widgets/player_shared_widgets.dart';
import 'widgets/progress_bar_widget.dart';

class MiniPlayerContent extends ConsumerWidget {
  final MediaItem currentSong;
  final PlayerState playerState;
  final VoidCallback? onTap;
  final VoidCallback? onPlayPause;
  final VoidCallback? onSkipNext;
  final VoidCallback? onSkipPrevious;
  final VoidCallback? onOpenLyrics;
  final VoidCallback? onOpenQueue;
  final ValueChanged<Duration>? onSeek;

  const MiniPlayerContent({
    super.key,
    required this.currentSong,
    required this.playerState,
    this.onTap,
    this.onPlayPause,
    this.onSkipNext,
    this.onSkipPrevious,
    this.onOpenLyrics,
    this.onOpenQueue,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSwitching = playerState.isBlocked;
    final window = MediaQuery.sizeOf(context);

    if (isCompactShell(window)) {
      return const PlayerSheetMobile();
    } else if (isTabletShell(window)) {
      return _tabletLayout(context, ref, isSwitching);
    }
    return _desktopLayout(context, ref, isSwitching);
  }

  // ── Tablet and wide shelf (≥600px) ──────────────────────────────

  Widget _tabletLayout(BuildContext context, WidgetRef ref, bool isSwitching) {
    return _shelfLayout(context, ref, isSwitching, compact: true);
  }

  Widget _desktopLayout(BuildContext context, WidgetRef ref, bool isSwitching) {
    return _shelfLayout(context, ref, isSwitching, compact: false);
  }

  /// Edge-to-edge shelf: art + catalog metadata + like on the left, transport
  /// and seek in the center, expand / lyrics / queue / cast on the right.
  Widget _shelfLayout(
    BuildContext context,
    WidgetRef ref,
    bool isSwitching, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final track = QueueTrack.fromMediaItem(currentSong);
    final activeView = ref.watch(playerSubViewProvider);
    final accent = cs.brightness == Brightness.dark
        ? SonoraPulseTokens.primaryContainer
        : cs.primary;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (isSwitching) return;
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -250) {
          HapticFeedback.lightImpact();
          onSkipNext?.call();
        } else if (details.primaryVelocity! > 250) {
          HapticFeedback.lightImpact();
          onSkipPrevious?.call();
        }
      },
      child: _glassBar(
        child: isSwitching
            ? const ShimmerLoading(variant: ShimmerVariant.miniPlayer)
            : Row(
                children: [
                  Expanded(
                    flex: compact ? 5 : 4,
                    child: _ShelfIdentity(
                      track: track,
                      theme: theme,
                      cs: cs,
                      artwork: _artwork(
                        size: compact ? 48 : 56,
                        radius: 12,
                        cs: cs,
                        ref: ref,
                      ),
                      onOpenPlayer: isSwitching ? null : onTap,
                      like: MiniPlayerAffinityButton(song: currentSong),
                    ),
                  ),
                  Expanded(
                    flex: compact ? 4 : 5,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _iconButton(
                              icon: LucideIcons.skipBack,
                              color: cs.onSurfaceVariant,
                              onPressed: onSkipPrevious,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            _playPauseButton(cs, ref),
                            const SizedBox(width: 4),
                            _iconButton(
                              icon: LucideIcons.skipForward,
                              color: cs.onSurfaceVariant,
                              onPressed: onSkipNext,
                              size: 20,
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ProgressBarWidget(
                            position: playerState.position,
                            duration: playerState.duration,
                            disabled: playerState.isRestoring || isSwitching,
                            isPlaying: playerState.isPlaying,
                            density: ProgressBarDensity.comfortable,
                            onSeek: onSeek,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _iconButton(
                              icon: LucideIcons.maximize2,
                              color: cs.onSurfaceVariant,
                              onPressed: isSwitching ? null : onTap,
                              tooltip: AppLocalizations.of(context)!.openPlayer,
                            ),
                            _iconButton(
                              icon: LucideIcons.micVocal,
                              color: activeView == PlayerSubView.lyrics
                                  ? accent
                                  : cs.onSurfaceVariant,
                              onPressed: onOpenLyrics,
                              size: 20,
                            ),
                            _iconButton(
                              icon: LucideIcons.listMusic,
                              color: activeView == PlayerSubView.queue
                                  ? accent
                                  : cs.onSurfaceVariant,
                              onPressed: onOpenQueue,
                              size: 20,
                            ),
                            CastButton(
                              size: 20,
                              color: cs.onSurfaceVariant,
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                minimumSize: const Size(36, 36),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            if (!compact)
                              _iconButton(
                                icon: LucideIcons.moreVertical,
                                color: cs.onSurfaceVariant,
                                onPressed: () => _openTrackMenu(context, track),
                                size: 20,
                              ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _openTrackMenu(BuildContext context, QueueTrack track) {
    if (track.isEpisode) {
      ContextMenuSheet.showForEpisode(
        context,
        videoId: track.videoId,
        name: track.title,
        podcastName: track.artist,
        podcastBrowseId: track.podcastBrowseId,
        thumbnailUrl: track.artUri?.toString(),
        date: track.publishDate,
      );
      return;
    }
    ContextMenuSheet.showForSong(
      context,
      videoId: track.videoId,
      title: track.title,
      artist: track.artist ?? '',
      artistsJson: track.artistsJson,
      artistId: track.artistId,
      albumId: track.albumId,
      thumbnailUrl: track.artUri?.toString(),
      duration: track.duration?.inSeconds,
      albumName: track.album ?? '',
      isVideo: track.isVideo,
      isExplicit: track.isExplicit,
    );
  }

  // ── Shared Widgets ──────────────────────────────────────────────

  /// Shelf height. Colour and blur live on [PlayerSheet].
  Widget _glassBar({required Widget child}) {
    return SizedBox(height: kMiniPlayerShelfHeight, child: child);
  }

  Widget _artwork({
    required double size,
    required double radius,
    required ColorScheme cs,
    required WidgetRef ref,
  }) {
    final useVinylSetting = ref.watch(
      settingsProvider.select((s) => s.useVinylStyle),
    );
    final isEpisode = QueueTrack.fromMediaItem(currentSong).isEpisode;
    final useVinylStyle = useVinylSetting && !isEpisode;
    if (useVinylStyle) {
      return VinylArtwork(
        imageUrl: currentSong.artUri?.toString(),
        size: size,
        isPlaying: playerState.isPlaying,
        useShadow: false,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: currentSong.artUri != null
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: CachedNetworkImage(
                  key: ValueKey(currentSong.artUri!.toString()),
                  imageUrl: currentSong.artUri!.toString(),
                  fit: BoxFit.cover,
                  placeholder: (_, _) =>
                      Container(color: cs.surfaceContainerHighest),
                  errorWidget: (_, _, _) =>
                      Icon(LucideIcons.music, color: cs.onSurfaceVariant),
                ),
              )
            : Icon(LucideIcons.music, color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _playPauseButton(ColorScheme cs, [WidgetRef? ref]) {
    final blocked = playerState.isBlocked;
    final glow =
        ref == null ||
        !ref.watch(settingsProvider.select((s) => s.reduceEffects));
    return Container(
      width: 40,
      height: 40,
      decoration: SonoraPulseTokens.playControlDecoration(
        enabled: !blocked,
        glow: glow,
      ),
      child: IconButton(
        icon: AnimatedPlayPauseIcon(
          isPlaying: playerState.isPlaying,
          isLoading: playerState.isRestoring,
          color: SonoraPulseTokens.onPrimary,
          size: 22,
        ),
        onPressed: blocked
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPlayPause?.call();
              },
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: SonoraPulseTokens.onPrimary,
          fixedSize: const Size(40, 40),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    double size = 20,
    bool haptic = false,
    String? tooltip,
  }) {
    return IconButton(
      icon: Icon(icon, size: size),
      color: color,
      tooltip: tooltip,
      onPressed: onPressed != null && haptic
          ? () {
              HapticFeedback.lightImpact();
              onPressed();
            }
          : onPressed,
      style: IconButton.styleFrom(
        foregroundColor: color,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(36, 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// Left cluster of the shelf: artwork, tappable title / artist / album, like.
class _ShelfIdentity extends StatelessWidget {
  final QueueTrack track;
  final ThemeData theme;
  final ColorScheme cs;
  final Widget artwork;
  final VoidCallback? onOpenPlayer;
  final Widget like;

  const _ShelfIdentity({
    required this.track,
    required this.theme,
    required this.cs,
    required this.artwork,
    required this.onOpenPlayer,
    required this.like,
  });

  @override
  Widget build(BuildContext context) {
    final accent = cs.brightness == Brightness.dark
        ? SonoraPulseTokens.primaryContainer
        : cs.primary;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.15,
    );
    final link = muted?.copyWith(color: accent);

    final artistLabel = track.artist ?? '';
    VoidCallback? artistTap;
    if (track.isEpisode) {
      final id = track.podcastBrowseId;
      if (id != null && id.isNotEmpty) {
        artistTap = () => context.push('/podcast/$id');
      }
    } else {
      final id = track.artistId;
      if (id != null && id.isNotEmpty) {
        artistTap = () => context.push('/artist/$id');
      }
    }

    String? albumText;
    VoidCallback? albumTap;
    if (!track.isEpisode) {
      final albumId = track.albumId;
      final name = track.album;
      if (name != null && name.isNotEmpty) {
        albumText = name;
      }
      if (albumId != null && albumId.isNotEmpty) {
        albumTap = () => context.push('/album/$albumId');
        albumText ??= AppLocalizations.of(context)!.fromTheAlbum;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          GestureDetector(onTap: onOpenPlayer, child: artwork),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onOpenPlayer,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          track.title,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (track.isExplicit)
                        const ExplicitBadge(leading: SizedBox(width: 6)),
                      if (track.isVideo)
                        const VideoBadge(leading: SizedBox(width: 6)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (artistLabel.isNotEmpty)
                      Flexible(
                        child: _MetaLink(
                          key: const ValueKey('mini-artist-link'),
                          label: artistLabel,
                          style: artistTap == null ? muted : link,
                          onTap: artistTap,
                        ),
                      ),
                    if (albumText != null) ...[
                      if (artistLabel.isNotEmpty) Text(' · ', style: muted),
                      Flexible(
                        child: _MetaLink(
                          key: const ValueKey('mini-album-link'),
                          label: albumText,
                          style: albumTap == null ? muted : link,
                          onTap: albumTap,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          like,
        ],
      ),
    );
  }
}

class _MetaLink extends StatelessWidget {
  final String label;
  final TextStyle? style;
  final VoidCallback? onTap;

  const _MetaLink({super.key, required this.label, this.style, this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    if (onTap == null) return text;
    return GestureDetector(onTap: onTap, child: text);
  }
}

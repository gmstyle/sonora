import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/extensions/duration_ext.dart';
import '../../../core/extensions/stat_format.dart';
import '../../../core/theme/sonora_pulse_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/player_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/action_feedback_provider.dart';
import 'context_menu_sheet.dart';
import 'thumbnail_widget.dart';
import 'video_badge.dart';
import 'explicit_badge.dart';

class SongTile extends ConsumerWidget {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final int? duration;
  final bool isVideo;
  final String? albumName;
  final String? artistId;
  final String? albumId;
  final List<ArtistBasic>? artists;
  final String? artistsJson;
  final String? playCount;
  final int? viewCount;
  final bool isExplicit;
  final bool isPlayable;
  final int? index;
  final Widget? leadingOverride;
  final List<Widget>? trailingActions;
  final VoidCallback? onTap;

  /// Pulse track-row card (Stitch continue-listening): white/surface fill,
  /// radius 12, light shadow. Flat [ListTile] when false (album/playlist lists).
  final bool elevated;

  const SongTile({
    super.key,
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.duration,
    this.isVideo = false,
    this.albumName,
    this.artistId,
    this.albumId,
    this.artists,
    this.artistsJson,
    this.playCount,
    this.viewCount,
    this.isExplicit = false,
    this.isPlayable = true,
    this.index,
    this.leadingOverride,
    this.trailingActions,
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statLabel = _formatStat();
    final downloadedIds = ref.watch(downloadedIdsProvider);
    final isDownloaded = downloadedIds.contains(videoId);
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;

    final tile = ListTile(
      contentPadding: elevated
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 2)
          : null,
      visualDensity: elevated ? VisualDensity.compact : null,
      minVerticalPadding: elevated ? 8 : null,
      leading: leadingOverride ?? _buildLeading(context, isDownloaded),
      title: Text.rich(
        TextSpan(
          children: [
            if (isExplicit)
              const WidgetSpan(
                child: Padding(
                  padding: EdgeInsets.only(right: 6.0),
                  child: ExplicitBadge(),
                ),
                alignment: PlaceholderAlignment.middle,
              ),
            TextSpan(text: title),
          ],
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: Text(
        [artist, if (albumName != null) albumName, ?statLabel].join(' · '),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: colors.onSurfaceVariant),
      ),
      trailing: _buildTrailing(context),
      onTap: !isPlayable
          ? () {
              final l10n = AppLocalizations.of(context);
              if (l10n != null) {
                ref
                    .read(actionFeedbackProvider.notifier)
                    .report(
                      l10n.trackUnplayable(title),
                      kind: FeedbackKind.error,
                    );
              }
            }
          : onTap ??
                () => ref
                    .read(playerStateProvider.notifier)
                    .playVideoId(
                      videoId,
                      isVideo: isVideo,
                      isExplicit: isExplicit,
                    ),
      onLongPress: () => ContextMenuSheet.showForSong(
        context,
        videoId: videoId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
        duration: duration,
        isVideo: isVideo,
        albumName: albumName,
        artistId: artistId,
        albumId: albumId,
        artists: artists,
        artistsJson: artistsJson,
        playCount: playCount,
        viewCount: viewCount,
        isExplicit: isExplicit,
        isPlayable: isPlayable,
      ),
    );

    Widget result = tile;
    if (elevated) {
      final cardColor = isDark
          ? colors.surfaceContainer
          : colors.surfaceContainerLowest;
      result = Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: cardColor,
          elevation: isDark ? 0 : 1,
          shadowColor: colors.shadow.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SonoraPulseTokens.radiusSm),
            side: BorderSide(
              color: colors.outlineVariant.withValues(
                alpha: isDark ? 0.5 : 0.9,
              ),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: tile,
        ),
      );
    }

    if (isPlayable) return result;
    return Opacity(opacity: 0.5, child: result);
  }

  Widget _buildLeading(BuildContext context, bool isDownloaded) {
    final thumbnail = Stack(
      children: [
        ThumbnailWidget(
          imageUrl: thumbnailUrl,
          size: 48,
          shape: ThumbnailShape.rounded,
        ),
        if (isVideo)
          Positioned(
            bottom: 0,
            right: isDownloaded ? null : 0,
            left: isDownloaded ? 0 : null,
            child: const VideoBadge(
              padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              borderRadius: 3,
            ),
          ),
        if (isDownloaded)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.download,
                size: 10,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
      ],
    );

    if (index != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$index',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          thumbnail,
        ],
      );
    }

    return thumbnail;
  }

  String? _formatStat() {
    if (playCount != null && playCount!.isNotEmpty) {
      return stripYtLabel(playCount);
    }
    if (viewCount != null) return viewCount!.toCompact();
    return null;
  }

  Widget? _buildTrailing(BuildContext context) {
    final hasDuration = duration != null;
    final hasActions = trailingActions != null && trailingActions!.isNotEmpty;
    final banIcon = !isPlayable
        ? Icon(
            LucideIcons.ban,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          )
        : null;

    if (!hasDuration && !hasActions && banIcon == null) return null;

    final durationWidget = hasDuration
        ? Text(
            Duration(seconds: duration!).format(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?durationWidget,
        if (banIcon != null) ...[
          if (durationWidget != null) const SizedBox(width: 8),
          banIcon,
        ],
        if (hasActions) ...[
          if (durationWidget != null || banIcon != null)
            const SizedBox(width: 8),
          ...trailingActions!,
        ],
      ],
    );
  }
}

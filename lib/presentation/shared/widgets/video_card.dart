import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/player_provider.dart';
import '../../providers/action_feedback_provider.dart';
import 'context_menu_sheet.dart';
import 'scale_button.dart';
import 'video_badge.dart';
import 'explicit_badge.dart';

class VideoCard extends ConsumerWidget {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final String? artistId;
  final List<ArtistBasic>? artists;
  final String? artistsJson;
  final bool isExplicit;
  final bool isPlayable;
  final double cardWidth;

  const VideoCard({
    super.key,
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.artistId,
    this.artists,
    this.artistsJson,
    this.isExplicit = false,
    this.isPlayable = true,
    this.cardWidth = 200,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final card = ScaleButton(
      onTap:
          !isPlayable
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
              : () => ref
                  .read(playerStateProvider.notifier)
                  .playVideoId(videoId, isVideo: true, isExplicit: isExplicit),
      onLongPress:
          () => ContextMenuSheet.showForSong(
            context,
            videoId: videoId,
            title: title,
            artist: artist,
            thumbnailUrl: thumbnailUrl,
            isVideo: true,
            artistId: artistId,
            artists: artists,
            artistsJson: artistsJson,
            isExplicit: isExplicit,
            isPlayable: isPlayable,
          ),
      child: SizedBox(
        width: cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnailUrl != null)
                      CachedNetworkImage(
                        imageUrl: thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget:
                            (_, _, _) => Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                LucideIcons.music,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                      )
                    else
                      Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          LucideIcons.music,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const Positioned(
                      bottom: 4,
                      left: 4,
                      child: VideoBadge(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        borderRadius: 3,
                      ),
                    ),
                    if (!isPlayable)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(
                          LucideIcons.ban,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text.rich(
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
              maxLines: 2,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              artist,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );

    if (isPlayable) return card;
    return Opacity(opacity: 0.5, child: card);
  }
}

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/player_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../shared/widgets/context_menu_sheet.dart';

class TopBar extends ConsumerWidget {
  const TopBar({
    super.key,
    required this.currentSong,
    required this.isVideo,
    required this.albumName,
    this.onClose,
  });

  final MediaItem currentSong;
  final bool isVideo;
  final String? albumName;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pc = PlayerColors.of(context);
    final videoId = currentSong.extras?['videoId'] as String? ?? currentSong.id;
    final artistId = currentSong.extras?['artistId'] as String?;
    final albumId = currentSong.extras?['albumId'] as String?;
    final album = albumName;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(LucideIcons.chevronDown, color: pc.iconPrimary),
          onPressed: onClose ?? () => Navigator.of(context).pop(),
          tooltip: AppLocalizations.of(context)!.close,
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.playingFrom,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: pc.subtitle,
                  letterSpacing: 1.2,
                ),
              ),
              if (album != null)
                Text(
                  album,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: pc.titlePrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Text(
                  AppLocalizations.of(context)!.nowPlaying,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: pc.titlePrimary,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(LucideIcons.moreVertical, color: pc.iconPrimary),
          onPressed: () {
            final router = GoRouter.of(context);
            ContextMenuSheet.showForNowPlaying(
              context,
              videoId: videoId,
              title: currentSong.title,
              artist: currentSong.artist ?? '',
              thumbnailUrl: currentSong.artUri?.toString(),
              duration: currentSong.duration?.inSeconds,
              albumName: albumName,
              isVideo: isVideo,
              artistId: artistId,
              albumId: albumId,
              isExplicit: currentSong.extras?['isExplicit'] == true,
              onGoToArtist: (artistId) {
                Navigator.of(context).pop();
                router.push('/artist/$artistId');
              },
              onGoToAlbum: (albumId) {
                Navigator.of(context).pop();
                router.push('/album/$albumId');
              },
            );
          },
        ),
      ],
    );
  }
}

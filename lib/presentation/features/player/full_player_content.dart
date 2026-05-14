import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/player_provider.dart';
import 'widgets/player_controls.dart';
import 'widgets/progress_bar_widget.dart';
import 'widgets/queue_sheet.dart';
import 'widgets/lyrics_view.dart';

class FullPlayerContent extends ConsumerStatefulWidget {
  const FullPlayerContent({super.key});

  @override
  ConsumerState<FullPlayerContent> createState() => _FullPlayerContentState();
}

class _FullPlayerContentState extends ConsumerState<FullPlayerContent> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final currentSong = playerState.currentSong;

    if (currentSong == null) return const SizedBox.shrink();

    final isVideo = currentSong.extras?['isVideo'] == true;
    final videoId =
        currentSong.extras?['videoId'] as String? ?? currentSong.id;
    final artUrl = currentSong.artUri?.toString();
    final albumName = currentSong.album;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildArtwork(context, artUrl),
            const SizedBox(height: 16),
            _buildTrackInfo(context, currentSong, isVideo, albumName),
            const SizedBox(height: 8),
            ProgressBarWidget(
              position: playerState.position,
              duration: playerState.duration,
              seed: videoId.hashCode,
              onSeek:
                  (pos) => ref.read(playerStateProvider.notifier).seek(pos),
            ),
            const SizedBox(height: 4),
            PlayerControls(),
            const SizedBox(height: 4),
            _buildLikeButton(context, videoId, isVideo),
            const SizedBox(height: 16),
            _buildTabButtons(context, isVideo),
            _buildTabContent(context, videoId, playerState, isVideo),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildArtwork(BuildContext context, String? artUrl) {
    return Center(
      child: Hero(
        tag: 'player_art',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 280,
            height: 280,
            child: artUrl != null
                ? CachedNetworkImage(
                    imageUrl: artUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    errorWidget: (_, _, _) => Icon(
                      Icons.music_note,
                      size: 80,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : Icon(
                    Icons.music_note,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackInfo(
    BuildContext context,
    MediaItem currentSong,
    bool isVideo,
    String? albumName,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  currentSong.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              if (isVideo) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'MV',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            currentSong.artist ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (albumName != null) ...[
            const SizedBox(height: 2),
            Text(
              albumName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLikeButton(
    BuildContext context,
    String videoId,
    bool isVideo,
  ) {
    return IconButton(
      icon: Icon(
        Icons.favorite_border,
        size: 24,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () {
        // Like functionality via context menu / library integration
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Like — coming in Fase 7 (Library)'),
            duration: Duration(seconds: 1),
          ),
        );
      },
    );
  }

  Widget _buildTabButtons(BuildContext context, bool isVideo) {
    final tabs = <String>['Now Playing'];
    if (!isVideo) tabs.add('Lyrics');
    tabs.add('Queue');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final isSelected = _selectedTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              child: Column(
                children: [
                  Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    String videoId,
    PlayerState playerState,
    bool isVideo,
  ) {
    final tabs = <Widget>[];
    tabs.add(const SizedBox(height: 16, child: SizedBox.shrink()));

    if (!isVideo) {
      tabs.add(
        SizedBox(
          height: 300,
          child: LyricsView(videoId: videoId, position: playerState.position),
        ),
      );
    }

    tabs.add(
      SizedBox(
        height: 300,
        child: QueueSheet(),
      ),
    );

    final idx =
        _selectedTab.clamp(0, tabs.length - 1);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(
        key: ValueKey(idx),
        child: tabs[idx],
      ),
    );
  }
}

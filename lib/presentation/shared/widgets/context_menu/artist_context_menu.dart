import 'dart:async';

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/extensions/stat_format.dart';
import '../../../../core/link/sonora_link.dart';
import '../../../../domain/repositories/music_repository.dart';
import '../../../../domain/usecases/player/play_album_use_case.dart';
import '../../../../domain/usecases/player/start_radio_use_case.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../features/artist/providers/artist_provider.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../providers/music_repository_provider.dart';
import '../../../providers/play_album_use_case_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/start_radio_use_case_provider.dart';
import '../detail_actions_bar.dart';
import '../thumbnail_widget.dart';
import 'action_tiles.dart';
import 'context_menu_presenter.dart';

class ArtistContextMenuSheet extends ConsumerWidget {
  final String artistId;
  final String name;
  final String? thumbnailUrl;
  final String? monthlyListeners;
  final bool hideGoToArtist;
  final Set<String> omitActionIds;

  const ArtistContextMenuSheet({
    super.key,
    required this.artistId,
    required this.name,
    this.thumbnailUrl,
    this.monthlyListeners,
    this.hideGoToArtist = false,
    this.omitActionIds = const {},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                ThumbnailWidget(
                  imageUrl: thumbnailUrl,
                  size: 48,
                  shape: ThumbnailShape.circle,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (monthlyListeners != null &&
                          monthlyListeners!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          stripYtLabel(monthlyListeners) ?? '',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showAction(omitActionIds, DetailActionId.play))
                    ActionTile(
                      icon: LucideIcons.play,
                      label: AppLocalizations.of(context)!.playTopSongs,
                      onTap: () {
                        final artistFuture = ref.read(
                          artistProvider(artistId).future,
                        );
                        final repo = ref.read(musicRepositoryProvider);
                        final player = ref.read(playerStateProvider.notifier);
                        final useCase = ref.read(playAlbumUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final l10n = AppLocalizations.of(context)!;
                        Navigator.pop(context);
                        _playTopSongs(
                          artistFuture,
                          repo,
                          useCase,
                          player,
                          feedback,
                          l10n,
                        );
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.shuffle))
                    ActionTile(
                      icon: LucideIcons.shuffle,
                      label: AppLocalizations.of(context)!.shuffle,
                      onTap: () {
                        final artistFuture = ref.read(
                          artistProvider(artistId).future,
                        );
                        final repo = ref.read(musicRepositoryProvider);
                        final player = ref.read(playerStateProvider.notifier);
                        final useCase = ref.read(playAlbumUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final l10n = AppLocalizations.of(context)!;
                        Navigator.pop(context);
                        _shufflePlay(
                          artistFuture,
                          repo,
                          useCase,
                          player,
                          feedback,
                          l10n,
                        );
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.queue))
                    ActionTile(
                      icon: LucideIcons.listMusic,
                      label: AppLocalizations.of(context)!.addToQueue,
                      onTap: () {
                        final artistFuture = ref.read(
                          artistProvider(artistId).future,
                        );
                        final repo = ref.read(musicRepositoryProvider);
                        final player = ref.read(playerStateProvider.notifier);
                        final useCase = ref.read(playAlbumUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final l10n = AppLocalizations.of(context)!;
                        Navigator.pop(context);
                        _addTopSongsToQueue(
                          artistFuture,
                          repo,
                          useCase,
                          player,
                          feedback,
                          l10n,
                        );
                      },
                    ),
                  if (!hideGoToArtist)
                    ActionTile(
                      icon: LucideIcons.user,
                      label: AppLocalizations.of(context)!.goToArtist,
                      onTap: () {
                        context.push('/artist/$artistId');
                        Navigator.pop(context);
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.save))
                    FollowArtistActionTile(
                      artistId: artistId,
                      name: name,
                      thumbnailUrl: thumbnailUrl,
                    ),
                  if (showAction(omitActionIds, DetailActionId.radio))
                    ActionTile(
                      icon: LucideIcons.radio,
                      label: AppLocalizations.of(context)!.artistRadio,
                      enabled: !isOffline,
                      onTap: () {
                        final artistFuture = ref.read(
                          artistProvider(artistId).future,
                        );
                        final player = ref.read(playerStateProvider.notifier);
                        final useCase = ref.read(startRadioUseCaseProvider);
                        final feedback = ref.read(
                          actionFeedbackProvider.notifier,
                        );
                        final l10n = AppLocalizations.of(context)!;
                        Navigator.pop(context);
                        _startRadio(
                          artistFuture,
                          useCase,
                          player,
                          feedback,
                          l10n,
                        );
                      },
                    ),
                  if (showAction(omitActionIds, DetailActionId.share))
                    ActionTile(
                      icon: LucideIcons.share2,
                      label: AppLocalizations.of(context)!.share,
                      onTap: () {
                        final share = shareSonoraLinkFromMenu(
                          ref,
                          context,
                          link: SonoraLink(
                            kind: SonoraLinkKind.artist,
                            id: artistId,
                          ),
                          title: name,
                        );
                        Navigator.pop(context);
                        unawaited(share);
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<SongDetailed>> _fetchSongs(
    Future<ArtistFull> artistFuture,
  ) async {
    final artist = await artistFuture;
    return artist.topSongs;
  }

  Future<List<SongDetailed>> _fetchAllTopSongs(
    Future<ArtistFull> artistFuture,
    MusicRepository repo,
  ) async {
    final artist = await artistFuture;
    try {
      final songs = await repo.getArtistSongs(artistId);
      if (songs.isNotEmpty) return songs;
    } catch (_) {}
    return artist.topSongs;
  }

  Future<void> _playTopSongs(
    Future<ArtistFull> artistFuture,
    MusicRepository repo,
    PlayAlbumUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      final songs = await _fetchAllTopSongs(artistFuture, repo);
      if (songs.isEmpty) return;
      feedback.report(l10n.playingArtist(name));
      await player.playAlbum(songs, startIndex: 0);
    } catch (e) {
      debugPrint('Failed to play: $e');
      feedback.report(l10n.failedToPlay, kind: FeedbackKind.error);
    }
  }

  Future<void> _shufflePlay(
    Future<ArtistFull> artistFuture,
    MusicRepository repo,
    PlayAlbumUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      final songs = await _fetchAllTopSongs(artistFuture, repo);
      if (songs.isEmpty) return;
      feedback.report(l10n.shufflingArtist(name));
      final shuffled = List<SongDetailed>.from(songs)..shuffle();
      await player.playAlbum(shuffled, startIndex: 0);
    } catch (e) {
      debugPrint('Failed to play: $e');
      feedback.report(l10n.failedToPlay, kind: FeedbackKind.error);
    }
  }

  Future<void> _addTopSongsToQueue(
    Future<ArtistFull> artistFuture,
    MusicRepository repo,
    PlayAlbumUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      final songs = await _fetchAllTopSongs(artistFuture, repo);
      if (songs.isEmpty) return;
      final items = await useCase.execute(songs, playIndex: -1);
      if (items.isNotEmpty) {
        await player.addAllToQueue(items);
        feedback.report(l10n.addedToQueue(items.length));
      }
    } catch (e) {
      debugPrint('Failed to add to queue: $e');
      feedback.report(l10n.failedToAddToQueue, kind: FeedbackKind.error);
    }
  }

  Future<void> _startRadio(
    Future<ArtistFull> artistFuture,
    StartRadioUseCase useCase,
    PlayerNotifier player,
    ActionFeedbackNotifier feedback,
    AppLocalizations l10n,
  ) async {
    try {
      final songs = await _fetchSongs(artistFuture);
      if (songs.isEmpty) return;
      final result = await useCase.execute(songs.first.videoId);
      await player.playNow([result.firstItem]);
      if (result.remaining.isNotEmpty) {
        final pendingItems = useCase.toPendingItems(result.remaining);
        player.addAllToQueue(pendingItems);
      }
    } catch (e) {
      debugPrint('Failed to start radio: $e');
      feedback.report(l10n.failedToStartRadio, kind: FeedbackKind.error);
    }
  }
}

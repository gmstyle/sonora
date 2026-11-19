import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../domain/models/library_models.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../providers/action_feedback_provider.dart';
import '../../../../providers/library_notifier.dart';
import '../../../../providers/player_provider.dart';
import '../../../../shared/widgets/context_menu_sheet.dart';
import '../../../../shared/widgets/error_retry_widget.dart';
import '../../../../shared/widgets/thumbnail_widget.dart';
import '../../../podcast/providers/episode_provider.dart';
import '../../tv_metrics.dart';
import '../../widgets/tv_entity_side_column.dart';
import '../../widgets/tv_focusable.dart';
import '../../widgets/tv_shimmer.dart';

/// Standalone 10-foot Split 40/60 Episode detail screen for Android TV.
class TvEpisodeScreen extends ConsumerWidget {
  final String videoId;

  const TvEpisodeScreen({super.key, required this.videoId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(episodeProvider(videoId));
    final l10n = AppLocalizations.of(context)!;

    return async.when(
      loading: () => const TvEntityShimmer(rowCount: 4),
      error: (e, _) => Scaffold(
        backgroundColor: TvColors.bg,
        body: ErrorRetryWidget(
          message: l10n.failedToLoadEpisode,
          onRetry: () => ref.invalidate(episodeProvider(videoId)),
        ),
      ),
      data: (episode) => _TvEpisodeBody(episode: episode),
    );
  }
}

class _TvEpisodeBody extends ConsumerStatefulWidget {
  final EpisodeFull episode;

  const _TvEpisodeBody({required this.episode});

  @override
  ConsumerState<_TvEpisodeBody> createState() => _TvEpisodeBodyState();
}

class _TvEpisodeBodyState extends ConsumerState<_TvEpisodeBody> {
  final FocusNode _playFocus = FocusNode(debugLabel: 'tvEpisodePlay');
  final ScrollController _notesScroll = ScrollController();
  bool _notesFocused = false;

  @override
  void dispose() {
    _playFocus.dispose();
    _notesScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final episode = widget.episode;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final liked = ref
        .watch(likedEpisodeProvider(episode.videoId))
        .asData
        ?.value;
    final art = episode.thumbnails.isNotEmpty
        ? episode.thumbnails.last.url
        : null;
    final notes = episode.description?.trim() ?? '';

    return Scaffold(
      backgroundColor: TvColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TvMetrics.overscanHorizontal,
            TvMetrics.overscanVertical,
            TvMetrics.overscanHorizontal,
            TvMetrics.overscanVertical,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column (Split 40%): Artwork, Meta & Action Stack
              TvEntitySideColumn(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TvFocusable(
                      onSelect: () => context.pop(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TvColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.chevronLeft,
                              size: 16,
                              color: TvColors.textPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.askIntroBack,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: TvColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: ThumbnailWidget(
                      imageUrl: art,
                      size: 164,
                      shape: ThumbnailShape.rounded,
                      borderRadius: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    episode.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: TvColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  if (episode.podcastName != null &&
                      episode.podcastName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      episode.podcastName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (episode.date != null && episode.date!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      episode.date!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: TvColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: 224,
                    child: Column(
                      children: [
                        TvFocusable(
                          focusNode: _playFocus,
                          autofocus: true,
                          onSelect: () => ref
                              .read(playerStateProvider.notifier)
                              .playVideoId(episode.videoId),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.play,
                                  size: 16,
                                  color: colorScheme.onPrimary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.playNow,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (episode.podcastId != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TvFocusable(
                              onSelect: () =>
                                  context.push('/podcast/${episode.podcastId}'),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: TvColors.border),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      LucideIcons.podcast,
                                      size: 15,
                                      color: TvColors.textPrimary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.goToPodcast,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: TvColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: TvFocusable(
                                onSelect: () {
                                  ref
                                      .read(libraryNotifierProvider.notifier)
                                      .toggleLikedEpisode(
                                        LikedEpisodeModel(
                                          videoId: episode.videoId,
                                          name: episode.name,
                                          podcastName: episode.podcastName,
                                          podcastBrowseId: episode.podcastId,
                                          thumbnailUrl: art,
                                          addedAt: DateTime.now(),
                                        ),
                                      );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: liked != null
                                        ? colorScheme.primary.withValues(
                                            alpha: 0.16,
                                          )
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: liked != null
                                          ? colorScheme.primary.withValues(
                                              alpha: 0.4,
                                            )
                                          : TvColors.borderSubtle,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        liked != null
                                            ? LucideIcons.bookmarkCheck
                                            : LucideIcons.bookmark,
                                        size: 15,
                                        color: liked != null
                                            ? colorScheme.primary
                                            : TvColors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        liked != null
                                            ? l10n.episodeSaved
                                            : l10n.save,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: liked != null
                                                  ? colorScheme.primary
                                                  : TvColors.textPrimary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TvFocusable(
                              onSelect: () {
                                ref
                                    .read(playerStateProvider.notifier)
                                    .addToQueueVideoId(
                                      episode.videoId,
                                      title: episode.name,
                                      artist: episode.podcastName ?? '',
                                      thumbnailUrl: art,
                                    );
                                ref
                                    .read(actionFeedbackProvider.notifier)
                                    .report(l10n.addedToQueue(1));
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: TvColors.borderSubtle,
                                  ),
                                ),
                                child: const Icon(
                                  LucideIcons.listMusic,
                                  size: 17,
                                  color: TvColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TvFocusable(
                              onSelect: () => ContextMenuSheet.showForEpisode(
                                context,
                                videoId: episode.videoId,
                                name: episode.name,
                                podcastName: episode.podcastName,
                                podcastBrowseId: episode.podcastId,
                                thumbnailUrl: art,
                                onGoToPodcast: (id) =>
                                    context.push('/podcast/$id'),
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: TvColors.borderSubtle,
                                  ),
                                ),
                                child: const Icon(
                                  LucideIcons.ellipsisVertical,
                                  size: 17,
                                  color: TvColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 32),

              // Right Column (Split 60%): D-Pad Scrollable Show Notes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        l10n.showNotes.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: TvColors.textSecondary,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: TvColors.border),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Focus(
                          onFocusChange: (v) {
                            if (_notesFocused != v) {
                              setState(() => _notesFocused = v);
                            }
                          },
                          onKeyEvent: (node, event) {
                            if (event is! KeyDownEvent &&
                                event is! KeyRepeatEvent) {
                              return KeyEventResult.ignored;
                            }
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowLeft) {
                              _playFocus.requestFocus();
                              return KeyEventResult.handled;
                            }
                            if (_notesScroll.hasClients) {
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowDown) {
                                _notesScroll.animateTo(
                                  (_notesScroll.offset + 100).clamp(
                                    0.0,
                                    _notesScroll.position.maxScrollExtent,
                                  ),
                                  duration: const Duration(milliseconds: 140),
                                  curve: Curves.easeOutCubic,
                                );
                                return KeyEventResult.handled;
                              }
                              if (event.logicalKey ==
                                  LogicalKeyboardKey.arrowUp) {
                                _notesScroll.animateTo(
                                  (_notesScroll.offset - 100).clamp(
                                    0.0,
                                    _notesScroll.position.maxScrollExtent,
                                  ),
                                  duration: const Duration(milliseconds: 140),
                                  curve: Curves.easeOutCubic,
                                );
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: AnimatedContainer(
                            duration: TvMetrics.drawerAnimDuration,
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: TvColors.surface.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _notesFocused
                                    ? colorScheme.primary
                                    : TvColors.border,
                                width: _notesFocused ? 2 : 1,
                              ),
                            ),
                            child: SingleChildScrollView(
                              controller: _notesScroll,
                              child: Text(
                                notes.isEmpty ? l10n.noShowNotes : notes,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: notes.isEmpty
                                      ? TvColors.textSecondary
                                      : TvColors.textPrimary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:audio_service/audio_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../domain/models/queue_track.dart';
import '../../../../core/theme/player_colors.dart';
import '../../../../core/extensions/duration_ext.dart';
import '../../../../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/player_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../shared/widgets/explicit_badge.dart';
import '../../../shared/widgets/shimmer_loading.dart';

const double _kQueueTileHeight = 68;
const double _kAccentRailWidth = 3;
const double _kSectionHeaderExtent = 48;
const double _kHintExtent = 40;

class QueueSheet extends ConsumerStatefulWidget {
  const QueueSheet({super.key});

  @override
  ConsumerState<QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends ConsumerState<QueueSheet> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _currentItemKey = GlobalKey();

  bool _userHasScrolled = false;
  bool _isProgrammaticScroll = false;
  bool _didInitialCenter = false;
  bool _revealList = false;
  int _centerRetries = 0;
  String? _lastTrackId;
  int? _lastTrackIndex;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isProgrammaticScroll) return;
    _userHasScrolled = true;
  }

  void _scheduleCenterOnCurrent({required bool force}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _centerOnCurrent(force: force);
    });
  }

  /// Scroll offset that places [tileTop] at the vertical center of the viewport.
  double _centeredOffsetForTileTop(double tileTop) {
    final viewport = _scrollController.position.viewportDimension;
    return tileTop + (_kQueueTileHeight / 2) - (viewport / 2);
  }

  /// Estimate the Y of the current tile's top inside the scroll content.
  /// Fixed tile/header extents keep this reliable even before the tile is built
  /// (lazy slivers), which is why ensureVisible alone failed on reopen.
  double _estimateCurrentTileTop({
    required int currentIndex,
    required int userCount,
    required int? upNextStartIndex,
    required bool userEmpty,
  }) {
    var y = _kSectionHeaderExtent; // "In coda" header

    if (userEmpty) {
      y += _kHintExtent;
    } else if (currentIndex < userCount) {
      return y + currentIndex * _kQueueTileHeight;
    } else {
      y += userCount * _kQueueTileHeight;
    }

    y += _kSectionHeaderExtent; // "Up Next" header

    final start = upNextStartIndex ?? userCount;
    final localIndex = (currentIndex - start).clamp(0, 1 << 30);
    return y + localIndex * _kQueueTileHeight;
  }

  int _resolveCurrentIndex(PlayerState playerState) {
    final currentIndex = playerState.currentIndex;
    final currentSongId = playerState.currentSong?.id;
    if (currentSongId != null &&
        currentIndex >= 0 &&
        currentIndex < playerState.queue.length &&
        playerState.queue[currentIndex].id == currentSongId) {
      return currentIndex;
    }
    if (currentSongId != null) {
      final byId = playerState.queue.indexWhere((e) => e.id == currentSongId);
      if (byId >= 0) return byId;
    }
    return currentIndex.clamp(0, (playerState.queue.length - 1).clamp(0, 1 << 30));
  }

  Future<void> _centerOnCurrent({required bool force}) async {
    if (!force && _userHasScrolled) return;

    if (!_scrollController.hasClients) {
      if (_centerRetries < 12) {
        _centerRetries++;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _centerOnCurrent(force: force);
        });
      }
      return;
    }

    final playerState = ref.read(playerStateProvider);
    if (playerState.queue.isEmpty) {
      if (!_revealList) setState(() => _revealList = true);
      return;
    }

    final index = _resolveCurrentIndex(playerState);
    final userCount = playerState.userQueue.length;
    final tileTop = _estimateCurrentTileTop(
      currentIndex: index,
      userCount: userCount,
      upNextStartIndex: playerState.upNextStartIndex,
      userEmpty: playerState.userQueue.isEmpty,
    );

    final maxExtent = _scrollController.position.maxScrollExtent;
    // Content extent may not be ready on the very first frame after open.
    if (maxExtent <= 0 && index > 1 && _centerRetries < 12) {
      _centerRetries++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _centerOnCurrent(force: force);
      });
      return;
    }

    final target = _centeredOffsetForTileTop(
      tileTop,
    ).clamp(0.0, maxExtent);

    _isProgrammaticScroll = true;
    _centerRetries = 0;
    try {
      // Jump first so lazy slivers build the current tile near the viewport
      // (and so reopen never flashes the top of the list).
      _scrollController.jumpTo(target);

      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;

      final ctx = _currentItemKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (mounted) {
        _isProgrammaticScroll = false;
        if (!_revealList) setState(() => _revealList = true);
      }
    }
  }

  void _onCurrentTrackChanged(String? songId, int index) {
    final changed = songId != _lastTrackId || index != _lastTrackIndex;
    if (!changed && _didInitialCenter) return;

    _lastTrackId = songId;
    _lastTrackIndex = index;
    _userHasScrolled = false;
    _didInitialCenter = true;
    _scheduleCenterOnCurrent(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    final pc = PlayerColors.of(context);
    final theme = Theme.of(context);

    final userQueue = playerState.userQueue;
    final upNextQueue = playerState.upNextQueue;
    final currentIndex = playerState.currentIndex;
    final currentSongId = playerState.currentSong?.id;
    final autoplayEnabled = ref.watch(
      settingsProvider.select((s) => s.autoPlayUpNext),
    );

    // Prefer index when it already points at currentSong; if index is stale
    // (e.g. cold-start queueIndex never published), fall back to identity so
    // the playing tile still matches the mini player.
    final indexPointsAtSong =
        currentSongId != null &&
        currentIndex >= 0 &&
        currentIndex < playerState.queue.length &&
        playerState.queue[currentIndex].id == currentSongId;
    bool isCurrentAt(int globalIndex, MediaItem item) {
      if (indexPointsAtSong) return globalIndex == currentIndex;
      if (currentSongId != null) return item.id == currentSongId;
      return globalIndex == currentIndex;
    }

    ref.listen(
      playerStateProvider.select(
        (s) => (
          s.currentIndex,
          s.currentSong?.id,
          s.isQueueSynced,
          s.isRestoring,
        ),
      ),
      (prev, next) {
        final (index, songId, synced, restoring) = next;
        if (restoring || !synced) return;
        _onCurrentTrackChanged(songId, index);
      },
    );

    // Re-open of the queue sub-view (widget may be remounted; also covers
    // cases where state is preserved across toggles).
    ref.listen(playerSubViewProvider, (prev, next) {
      if (next == PlayerSubView.queue && prev != PlayerSubView.queue) {
        _userHasScrolled = false;
        _didInitialCenter = false;
        _revealList = false;
        _centerRetries = 0;
        _scheduleCenterOnCurrent(force: true);
        _didInitialCenter = true;
      }
    });

    if (playerState.isRestoring || !playerState.isQueueSynced) {
      _didInitialCenter = false;
      _revealList = false;
      return const ShimmerLoading(variant: ShimmerVariant.queue);
    }
    if (userQueue.isEmpty && upNextQueue.isEmpty) {
      return _EmptyState(pc: pc);
    }

    // First ready frame: center even if listen didn't fire (same values).
    if (!_didInitialCenter) {
      final songId = currentSongId;
      final index = currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didInitialCenter) return;
        _onCurrentTrackChanged(songId, index);
      });
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_isProgrammaticScroll) return false;
        if (notification is UserScrollNotification ||
            (notification is ScrollUpdateNotification &&
                notification.dragDetails != null)) {
          _userHasScrolled = true;
        }
        return false;
      },
      child: Opacity(
        opacity: _revealList ? 1 : 0,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── Header "In coda" (user queue) ──────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                icon: LucideIcons.listMusic,
                title: AppLocalizations.of(context)!.playingNext,
                count: userQueue.length,
                pc: pc,
                theme: theme,
              ),
            ),
            if (userQueue.isNotEmpty)
              SliverReorderableList(
                itemCount: userQueue.length,
                itemExtent: _kQueueTileHeight,
                proxyDecorator:
                    (child, index, animation) =>
                        Material(color: Colors.transparent, child: child),
                onReorderItem: (oldIndex, newIndex) {
                  // Items in userQueue live at the head of the global queue
                  // (indices 0 .. upNextStartIndex-1, or the whole queue
                  // when upnext is empty).
                  final start =
                      playerState.upNextStartIndex ?? playerState.queue.length;
                  if (oldIndex < 0 || oldIndex >= start) return;
                  if (newIndex < 0 || newIndex > start) return;
                  if (oldIndex == newIndex) return;
                  notifier.moveQueueItem(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final item = userQueue[index];
                  final isCurrent = isCurrentAt(index, item);
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(
                      'user_${item.extras?['queueId'] ?? item.id}_$index',
                    ),
                    index: index,
                    child: _QueueItem(
                      key: isCurrent ? _currentItemKey : null,
                      item: item,
                      isCurrent: isCurrent,
                      pc: pc,
                      onRemove: () => notifier.removeAt(index),
                      onTap: () => notifier.skipToIndex(index),
                    ),
                  );
                },
              )
            else
              SliverToBoxAdapter(
                child: SizedBox(
                  height: _kHintExtent,
                  child: _Hint(
                    text: AppLocalizations.of(context)!.userQueueEmpty,
                    pc: pc,
                  ),
                ),
              ),

            // ── Header "Up Next" (autoplay) ────────────────────────────
            SliverToBoxAdapter(
              child: _SectionHeader(
                icon: LucideIcons.infinity,
                title: AppLocalizations.of(context)!.upNext,
                count: upNextQueue.length,
                pc: pc,
                theme: theme,
                autoplayEnabled: autoplayEnabled,
                onAutoplayToggle: () {
                  ref
                      .read(settingsProvider.notifier)
                      .setAutoPlayUpNext(!autoplayEnabled);
                },
              ),
            ),
            if (upNextQueue.isNotEmpty)
              SliverFixedExtentList(
                itemExtent: _kQueueTileHeight,
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = upNextQueue[index];
                  final globalIndex =
                      (playerState.upNextStartIndex ?? 0) + index;
                  final isCurrent = isCurrentAt(globalIndex, item);
                  return _QueueItem(
                    key:
                        isCurrent
                            ? _currentItemKey
                            : ValueKey(
                              'upnext_${item.extras?['queueId'] ?? item.id}_$index',
                            ),
                    item: item,
                    isCurrent: isCurrent,
                    pc: pc,
                    // Upnext items are not individually removable; disable
                    // autoplay to clear the section.
                    onRemove: null,
                    onTap: () => notifier.skipToIndex(globalIndex),
                  );
                }, childCount: upNextQueue.length),
              )
            else
              SliverToBoxAdapter(
                child: SizedBox(
                  height: _kHintExtent,
                  child: _Hint(
                    text:
                        autoplayEnabled
                            ? AppLocalizations.of(context)!.upNextWillPopulate
                            : AppLocalizations.of(context)!.autoplayDisabled,
                    pc: pc,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final PlayerColors pc;
  final ThemeData theme;
  final bool? autoplayEnabled;
  final VoidCallback? onAutoplayToggle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.pc,
    required this.theme,
    this.autoplayEnabled,
    this.onAutoplayToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kSectionHeaderExtent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
        child: Row(
          children: [
            Icon(icon, size: 18, color: pc.labelMuted),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: pc.labelMuted,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: pc.labelMuted.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: pc.labelMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (autoplayEnabled != null && onAutoplayToggle != null)
              IconButton(
                tooltip:
                    autoplayEnabled!
                        ? AppLocalizations.of(context)!.autoplayDisable
                        : AppLocalizations.of(context)!.autoplayEnable,
                icon: Icon(
                  autoplayEnabled!
                      ? LucideIcons.toggleRight
                      : LucideIcons.toggleLeft,
                  size: 22,
                  color: autoplayEnabled! ? pc.iconPrimary : pc.iconSecondary,
                ),
                onPressed: onAutoplayToggle,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Queue item ─────────────────────────────────────────────────────────────

class _QueueItem extends StatelessWidget {
  final MediaItem item;
  final bool isCurrent;
  final PlayerColors pc;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const _QueueItem({
    super.key,
    required this.item,
    required this.isCurrent,
    required this.pc,
    this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUpNext = item.extras?['section'] == 'upnext';
    final opacity =
        isCurrent
            ? 1.0
            : isUpNext
            ? 0.7
            : 0.9;
    final duration = item.duration;
    final durationLabel =
        duration != null && duration > Duration.zero ? duration.format() : null;
    final artist = item.artist ?? '';
    final subtitle = [
      if (artist.isNotEmpty) artist,
      if (durationLabel != null) durationLabel,
    ].join(' · ');

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCurrent ? null : onTap,
          child: SizedBox(
            height: _kQueueTileHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Accent rail — reserved width so cover aligns for all rows
                  SizedBox(
                    width: _kAccentRailWidth,
                    child:
                        isCurrent
                            ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: pc.iconPrimary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const SizedBox.expand(),
                            )
                            : null,
                  ),
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child:
                          item.artUri != null
                              ? CachedNetworkImage(
                                imageUrl: item.artUri!.toString(),
                                fit: BoxFit.cover,
                                errorWidget:
                                    (_, _, _) => Icon(
                                      LucideIcons.music,
                                      color: pc.iconSecondary,
                                    ),
                              )
                              : Icon(
                                LucideIcons.music,
                                color: pc.iconSecondary,
                              ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DefaultTextStyle(
                          style: TextStyle(
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w500,
                            color:
                                isCurrent ? pc.titlePrimary : pc.titleSecondary,
                            fontSize: 15,
                          ),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (QueueTrack.fromMediaItem(item).isExplicit)
                                  const WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: ExplicitBadge(),
                                    ),
                                  ),
                                TextSpan(text: item.title),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: pc.subtitle, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isCurrent)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        LucideIcons.play,
                        size: 20,
                        color: pc.iconPrimary,
                      ),
                    )
                  else if (onRemove == null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        LucideIcons.infinity,
                        size: 16,
                        color: pc.iconSecondary.withValues(alpha: 0.6),
                      ),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        LucideIcons.x,
                        size: 18,
                        color: pc.iconSecondary,
                      ),
                      onPressed: onRemove,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final PlayerColors pc;
  const _EmptyState({required this.pc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.listMusic, size: 40, color: pc.labelMuted),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.queueIsEmpty,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: pc.subtitle),
          ),
        ],
      ),
    );
  }
}

// ── Hint text under an empty section ───────────────────────────────────────

class _Hint extends StatelessWidget {
  final String text;
  final PlayerColors pc;
  const _Hint({required this.text, required this.pc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Text(text, style: TextStyle(color: pc.subtitle, fontSize: 13)),
    );
  }
}

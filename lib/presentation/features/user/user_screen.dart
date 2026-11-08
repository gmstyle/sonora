import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/layout_breakpoints.dart';
import '../../../core/link/sonora_link.dart';
import '../../../core/theme/player_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/widgets/error_retry_widget.dart';
import '../../shared/widgets/glass_app_bar_background.dart';
import '../../shared/widgets/hover_carousel_arrows.dart';
import '../../shared/widgets/entity_banner_header.dart';
import '../../shared/widgets/entity_wide_body.dart';
import '../../shared/widgets/playlist_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/thumbnail_widget.dart';
import '../../shared/widgets/video_card.dart';
import '../../providers/action_feedback_provider.dart';
import 'providers/user_provider.dart';
import '../../../core/utils/artists_utils.dart';

class UserScreen extends ConsumerWidget {
  final String channelId;

  const UserScreen({super.key, required this.channelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        if (isCompactShell(size)) {
          return _UserMobileLayout(
            channelId: channelId,
            contentWidth: constraints.maxWidth,
          );
        } else if (size.width < kExpandedBreakpoint) {
          return _UserTabletLayout(
            channelId: channelId,
            contentWidth: constraints.maxWidth,
          );
        } else {
          return _UserWideLayout(
            channelId: channelId,
            contentWidth: constraints.maxWidth,
          );
        }
      },
    );
  }
}

class _UserMobileLayout extends ConsumerWidget {
  final String channelId;
  final double contentWidth;

  const _UserMobileLayout({
    required this.channelId,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider(channelId));

    return userAsync.when(
      loading: () => const Scaffold(body: _UserShimmer()),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadUser,
          onRetry: () => ref.invalidate(userProvider(channelId)),
        ),
      ),
      data: (user) => _UserContent(user: user, contentWidth: contentWidth),
    );
  }
}

class _UserTabletLayout extends ConsumerWidget {
  final String channelId;
  final double contentWidth;

  const _UserTabletLayout({
    required this.channelId,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider(channelId));

    return userAsync.when(
      loading: () => const Scaffold(body: _UserShimmer()),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadUser,
          onRetry: () => ref.invalidate(userProvider(channelId)),
        ),
      ),
      data: (user) =>
          _UserContent(user: user, isTablet: true, contentWidth: contentWidth),
    );
  }
}

class _UserWideLayout extends ConsumerWidget {
  final String channelId;
  final double contentWidth;

  const _UserWideLayout({required this.channelId, required this.contentWidth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider(channelId));

    return userAsync.when(
      loading: () => const Scaffold(body: _UserShimmer()),
      error: (e, _) => Scaffold(
        body: ErrorRetryWidget(
          message: AppLocalizations.of(context)!.failedToLoadUser,
          onRetry: () => ref.invalidate(userProvider(channelId)),
        ),
      ),
      data: (user) =>
          _UserContent(user: user, isWide: true, contentWidth: contentWidth),
    );
  }
}

class _UserContent extends ConsumerStatefulWidget {
  final UserFull user;
  final bool isTablet;
  final bool isWide;
  final double contentWidth;

  const _UserContent({
    required this.user,
    required this.contentWidth,
    this.isTablet = false,
    this.isWide = false,
  });

  @override
  ConsumerState<_UserContent> createState() => _UserContentState();
}

class _UserContentState extends ConsumerState<_UserContent> {
  late final ScrollController _scrollController;
  late final ScrollController _videosScrollController;
  late final ScrollController _playlistsScrollController;
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _videosScrollController = ScrollController();
    _playlistsScrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _videosScrollController.dispose();
    _playlistsScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double expandedHeight = widget.isTablet || widget.isWide
        ? EntityBannerHeader.expandedHeight(
            wide: widget.isWide,
            hasActions: false,
          )
        : 340.0;
    final double collapsedHeight =
        kToolbarHeight + MediaQuery.of(context).padding.top;
    final double delta = expandedHeight - collapsedHeight;
    final double progress = (_scrollController.offset / delta).clamp(0.0, 1.0);
    if (progress != _scrollProgress) {
      setState(() {
        _scrollProgress = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _UserSliverAppBar(
            user: user,
            isTablet: widget.isTablet,
            isWide: widget.isWide,
            contentWidth: widget.contentWidth,
            scrollProgress: _scrollProgress,
          ),
          SliverPadding(
            padding: entityBodyPadding(
              widget.contentWidth,
              shellShortestSide: MediaQuery.sizeOf(context).shortestSide,
            ),
            sliver: SliverToBoxAdapter(child: _userBody(user, l10n)),
          ),
        ],
      ),
    );
  }

  Widget _userBody(UserFull user, AppLocalizations l10n) {
    if (user.videos.isEmpty && user.playlists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(l10n.noContentAvailable),
        ),
      );
    }

    final videos = user.videos.isNotEmpty ? _videosShelf(user, l10n) : null;
    final playlists = user.playlists.isNotEmpty
        ? _playlistsShelf(user, l10n)
        : null;
    final both = videos != null && playlists != null;

    return EntityWideBody(
      list: videos ?? playlists!,
      related: both ? playlists : null,
    );
  }

  Widget _videosShelf(UserFull user, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.videos,
          onShowAll: user.videosParams != null
              ? () {
                  final params = Uri.encodeComponent(user.videosParams!);
                  context.push('/user/${user.channelId}/videos?params=$params');
                }
              : null,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: HoverCarouselArrows(
            controller: _videosScrollController,
            scrollAmount: 600,
            child: ListView.separated(
              controller: _videosScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: user.videos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final video = user.videos[index];
                return VideoCard(
                  videoId: video.videoId,
                  title: video.name,
                  artist: displayArtists(video.artists),
                  thumbnailUrl: video.thumbnails.isNotEmpty
                      ? video.thumbnails.last.url
                      : null,
                  artistId: primaryArtistId(video.artists),
                  isExplicit: video.isExplicit,
                  isPlayable: video.isPlayable,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _playlistsShelf(UserFull user, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: l10n.playlists,
          onShowAll: user.playlistsParams != null
              ? () {
                  final params = Uri.encodeComponent(user.playlistsParams!);
                  context.push(
                    '/user/${user.channelId}/playlists?params=$params',
                  );
                }
              : null,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: HoverCarouselArrows(
            controller: _playlistsScrollController,
            scrollAmount: 480,
            child: ListView.separated(
              controller: _playlistsScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: user.playlists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final playlist = user.playlists[index];
                return PlaylistCard(
                  playlistId: playlist.playlistId,
                  name: playlist.name,
                  artist: displayArtists(playlist.artists),
                  thumbnailUrl: playlist.thumbnails.isNotEmpty
                      ? playlist.thumbnails.last.url
                      : null,
                  cardWidth: 150,
                  heroTag: 'user_playlist_${playlist.playlistId}',
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

String? _userThumbnailUrl(UserFull user) {
  if (user.videos.isNotEmpty && user.videos.first.thumbnails.isNotEmpty) {
    return user.videos.first.thumbnails.last.url;
  }
  if (user.playlists.isNotEmpty && user.playlists.first.thumbnails.isNotEmpty) {
    return user.playlists.first.thumbnails.last.url;
  }
  return null;
}

class _UserSliverAppBar extends ConsumerWidget {
  final UserFull user;
  final bool isTablet;
  final bool isWide;
  final double contentWidth;
  final double scrollProgress;

  const _UserSliverAppBar({
    required this.user,
    required this.contentWidth,
    this.isTablet = false,
    this.isWide = false,
    required this.scrollProgress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final iconColor = Color.lerp(
      Colors.white,
      theme.colorScheme.onSurface,
      scrollProgress,
    );
    final thumbnailUrl = _userThumbnailUrl(user);

    return SliverAppBar(
      expandedHeight: isTablet || isWide
          ? EntityBannerHeader.expandedHeight(wide: isWide, hasActions: false)
          : 340,
      pinned: true,
      iconTheme: IconThemeData(color: iconColor),
      foregroundColor: iconColor,
      title: AnimatedOpacity(
        opacity: scrollProgress > 0.8 ? (scrollProgress - 0.8) / 0.2 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Text(
          user.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(LucideIcons.share2),
          tooltip: l10n.share,
          onPressed: () async {
            final result = await shareSonoraLink(
              SonoraLink(kind: SonoraLinkKind.user, id: user.channelId),
              title: user.name,
            );
            if (result == SonoraShareResult.copied && context.mounted) {
              ref.read(actionFeedbackProvider.notifier).report(l10n.linkCopied);
            }
          },
        ),
      ],
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          GlassAppBarBackground(opacity: scrollProgress),
          FlexibleSpaceBar(
            background: _buildHeaderBackground(context, thumbnailUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBackground(BuildContext context, String? thumbnailUrl) {
    final isTabletOrWide = isTablet || isWide;
    final horizontalPad = entityHorizontalPadding(
      contentWidth,
      shellShortestSide: MediaQuery.sizeOf(context).shortestSide,
    );
    final theme = Theme.of(context);
    final colors = PlayerColors.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (!isTabletOrWide) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnailUrl != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Opacity(
                  opacity: 0.4,
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  theme.colorScheme.surface.withValues(alpha: 0.95),
                ],
              ),
            ),
          ),
          _artworkTopScrim(context),
          Positioned(
            top: 56 + MediaQuery.of(context).padding.top,
            bottom: 12,
            left: horizontalPad,
            right: horizontalPad,
            child: Opacity(
              opacity: (1.0 - scrollProgress * 1.5).clamp(0.0, 1.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _UserAvatar(thumbnailUrl: thumbnailUrl, size: 140),
                  const SizedBox(height: 14),
                  Text(
                    user.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.titlePrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.subscriberCount != null &&
                      user.subscriberCount!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${user.subscriberCount} ${l10n.subscribers}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.labelMuted,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    final avatarUrl = thumbnailUrl;
    return EntityBannerHeader(
      eyebrow: l10n.entityKindProfile,
      title: user.name,
      meta: user.subscriberCount != null && user.subscriberCount!.isNotEmpty
          ? Text(
              '${user.subscriberCount} ${l10n.subscribers}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.titleSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      imageUrl: avatarUrl,
      shape: EntityBannerArtShape.circle,
      placeholderIcon: LucideIcons.user,
      scrollProgress: scrollProgress,
      wide: isWide,
      contentWidth: contentWidth,
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String? thumbnailUrl;
  final double size;

  const _UserAvatar({required this.thumbnailUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: size > 150 ? 18 : 16,
            offset: Offset(0, size > 150 ? 8 : 6),
          ),
        ],
      ),
      child: ThumbnailWidget(
        imageUrl: thumbnailUrl,
        size: size,
        shape: ThumbnailShape.circle,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onShowAll;

  const _SectionHeader({required this.title, this.onShowAll});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (onShowAll != null)
            TextButton(
              onPressed: onShowAll,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.showAll,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UserShimmer extends StatelessWidget {
  const _UserShimmer();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                const _SectionHeader(title: ''),
                const SizedBox(height: 8),
                ShimmerLoading(variant: ShimmerVariant.carousel),
                const SizedBox(height: 24),
                const _SectionHeader(title: ''),
                const SizedBox(height: 8),
                ShimmerLoading(variant: ShimmerVariant.carousel),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Top dark scrim for artwork headers — reads colours from [PlayerColors].
Widget _artworkTopScrim(BuildContext context) {
  final pc = PlayerColors.of(context);
  return DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.20, 0.32],
        colors: [pc.topScrimStart, pc.topScrimMid, Colors.transparent],
      ),
    ),
  );
}

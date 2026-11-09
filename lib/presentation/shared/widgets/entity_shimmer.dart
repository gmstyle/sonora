import 'package:material_ui/material_ui.dart';

import '../../../core/theme/sonora_pulse_tokens.dart';
import '../../../core/utils/layout_breakpoints.dart';
import 'entity_banner_header.dart';
import 'entity_wide_body.dart';
import 'shimmer_loading.dart';

/// Which entity body the shared skeleton stands in for.
enum EntityShimmerKind {
  /// Album, playlist, podcast: actions and a track list.
  tracks,

  /// Episode: actions without shuffle, then note lines.
  episode,

  /// Profile: circle cover, no actions, two shelves.
  profile,

  /// Artist: photo header, actions, top songs, two shelves.
  artist,
}

/// Loading state for an entity page.
///
/// Picks the same header as the page: centered on compact, cover on tablet
/// and wide, photo for an artist. [DetailActionsBar] sits in the header on
/// tablet and wide, and in the body on compact. Profile has no actions.
class EntityShimmer extends StatelessWidget {
  final EntityShimmerKind kind;
  final double contentWidth;

  const EntityShimmer({
    super.key,
    required this.kind,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = isCompactShell(size);
    final wide = isWideShell(size);
    final layout = switch (kind) {
      EntityShimmerKind.artist => EntityBannerLayout.photo,
      _ when compact => EntityBannerLayout.centered,
      _ => EntityBannerLayout.cover,
    };
    final actionsInHeader = kind != EntityShimmerKind.profile && !compact;
    final showShuffle = kind != EntityShimmerKind.episode;
    final pad = entityHorizontalPadding(
      contentWidth,
      shellShortestSide: size.shortestSide,
    );
    final height = EntityBannerHeader.expandedHeight(
      wide: wide,
      hasActions: actionsInHeader,
      layout: layout,
    );

    return ShimmerLoading.wrap(
      context,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: height,
            flexibleSpace: _Header(
              layout: layout,
              wide: wide,
              pad: pad,
              circle: kind == EntityShimmerKind.profile,
              actions: actionsInHeader
                  ? _ActionsSkeleton(compact: false, showShuffle: showShuffle)
                  : null,
            ),
          ),
          SliverPadding(
            padding: entityBodyPadding(
              contentWidth,
              shellShortestSide: size.shortestSide,
            ),
            sliver: SliverToBoxAdapter(
              child: _Body(
                kind: kind,
                actions: kind != EntityShimmerKind.profile && compact
                    ? _ActionsSkeleton(compact: true, showShuffle: showShuffle)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final EntityBannerLayout layout;
  final bool wide;
  final double pad;
  final bool circle;
  final Widget? actions;

  const _Header({
    required this.layout,
    required this.wide,
    required this.pad,
    required this.circle,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return switch (layout) {
      EntityBannerLayout.photo => _photo(),
      EntityBannerLayout.centered => Padding(
        padding: EdgeInsets.fromLTRB(pad, top, pad, 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Art(size: 140, circle: circle),
            const SizedBox(height: 14),
            const _Bar(width: 160, height: 18),
            const SizedBox(height: 8),
            const _Bar(width: 100, height: 12),
          ],
        ),
      ),
      EntityBannerLayout.cover => Padding(
        padding: EdgeInsets.fromLTRB(pad, top + 12, pad, 8),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  _Art(size: wide ? 180 : 148, circle: circle),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FractionBar(widthFactor: 0.72, height: 22),
                        SizedBox(height: 8),
                        _FractionBar(widthFactor: 0.48, height: 14),
                        SizedBox(height: 6),
                        _FractionBar(widthFactor: 0.36, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ?actions,
          ],
        ),
      ),
    };
  }

  Widget _photo() {
    return Column(
      children: [
        const Expanded(
          child: SizedBox(
            key: Key('entity-shimmer-art'),
            width: double.infinity,
            child: ColoredBox(color: Colors.white),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Bar(width: 180, height: 22),
              const SizedBox(height: 8),
              const Row(
                children: [
                  _Bar(width: 56, height: 12),
                  SizedBox(width: 16),
                  _Bar(width: 56, height: 12),
                  SizedBox(width: 16),
                  _Bar(width: 56, height: 12),
                ],
              ),
              if (actions != null) ...[const SizedBox(height: 12), actions!],
            ],
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  final EntityShimmerKind kind;
  final Widget? actions;

  const _Body({required this.kind, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ?actions,
        switch (kind) {
          EntityShimmerKind.tracks => _tracks(8),
          EntityShimmerKind.episode => const _Notes(),
          EntityShimmerKind.profile => const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_Shelf(video: true), SizedBox(height: 24), _Shelf()],
          ),
          EntityShimmerKind.artist => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tracks(5),
              const SizedBox(height: 24),
              const _Shelf(),
              const SizedBox(height: 24),
              const _Shelf(),
            ],
          ),
        },
      ],
    );
  }

  Widget _tracks(int count) {
    return Column(
      children: [for (var i = 0; i < count; i++) const _TrackRow()],
    );
  }
}

class _ActionsSkeleton extends StatelessWidget {
  final bool compact;
  final bool showShuffle;

  const _ActionsSkeleton({required this.compact, required this.showShuffle});

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('entity-shimmer-actions'),
      child: compact ? _compact() : _wide(),
    );
  }

  Widget _compact() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Disc(size: 40),
              const _Disc(size: 40),
              if (showShuffle) const _Disc(size: 40),
              const _Disc(size: 40),
            ],
          ),
          const _Disc(size: 56),
        ],
      ),
    );
  }

  Widget _wide() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const _Pill(width: 96),
          if (showShuffle) const _Pill(width: 120),
          const _Pill(width: 96),
          const _Pill(width: 96),
          const _Disc(size: 40),
        ],
      ),
    );
  }
}

class _Art extends StatelessWidget {
  final double size;
  final bool circle;

  const _Art({required this.size, required this.circle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('entity-shimmer-art'),
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle
              ? null
              : BorderRadius.circular(SonoraPulseTokens.radiusMedia),
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 72,
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(
                    Radius.circular(SonoraPulseTokens.radiusSm),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.72,
                      child: SizedBox(
                        height: 16,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.45,
                      child: SizedBox(
                        height: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            _Bar(width: 36, height: 12),
          ],
        ),
      ),
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Bar(width: double.infinity, height: 12),
        SizedBox(height: 8),
        _Bar(width: double.infinity, height: 12),
        SizedBox(height: 8),
        FractionallySizedBox(
          widthFactor: 0.72,
          alignment: Alignment.centerLeft,
          child: SizedBox(height: 12, child: ColoredBox(color: Colors.white)),
        ),
      ],
    );
  }
}

class _Shelf extends StatelessWidget {
  final bool video;

  const _Shelf({this.video = false});

  @override
  Widget build(BuildContext context) {
    final cardWidth = video ? 200.0 : 140.0;
    final coverHeight = video ? cardWidth * 9 / 16 : cardWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Bar(width: 120, height: 16),
        const SizedBox(height: 12),
        SizedBox(
          height: coverHeight + 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, _) => SizedBox(
              width: cardWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: coverHeight,
                    width: cardWidth,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(
                          Radius.circular(SonoraPulseTokens.radiusMedia),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Bar(width: cardWidth * 0.75, height: 14),
                  const SizedBox(height: 2),
                  _Bar(width: cardWidth * 0.5, height: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FractionBar extends StatelessWidget {
  final double widthFactor;
  final double height;

  const _FractionBar({required this.widthFactor, required this.height});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: height,
        child: const ColoredBox(color: Colors.white),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double width;
  final double height;

  const _Bar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final double width;

  const _Pill({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SonoraPulseTokens.radiusPill),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  final double size;

  const _Disc({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      ),
    );
  }
}

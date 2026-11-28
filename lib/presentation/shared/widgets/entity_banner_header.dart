import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/player_colors.dart';
import '../../../core/theme/sonora_pulse_tokens.dart';
import '../../providers/palette_provider.dart';
import 'entity_wide_body.dart';
import 'explicit_badge.dart';
import 'glass_app_bar_background.dart';

/// Cover shape for [EntityBannerHeader] when the layout is not [EntityBannerLayout.photo].
enum EntityBannerArtShape { circle, rounded }

/// Shared pinned [SliverAppBar] chrome for entity pages.
class EntitySliverAppBar extends StatelessWidget {
  final double expandedHeight;
  final double scrollProgress;
  final Widget collapsedTitle;
  final Widget background;
  final List<Widget>? actions;

  const EntitySliverAppBar({
    super.key,
    required this.expandedHeight,
    required this.scrollProgress,
    required this.collapsedTitle,
    required this.background,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = Color.lerp(
      Colors.white,
      theme.colorScheme.onSurface,
      scrollProgress,
    );

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: iconColor),
      foregroundColor: iconColor,
      actions: actions,
      title: AnimatedOpacity(
        opacity: scrollProgress > 0.8 ? (scrollProgress - 0.8) / 0.2 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: DefaultTextStyle.merge(
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
          child: collapsedTitle,
        ),
      ),
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          GlassAppBarBackground(
            opacity: scrollProgress > 0.6 ? (scrollProgress - 0.6) / 0.4 : 0.0,
          ),
          FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: background,
          ),
        ],
      ),
    );
  }
}

/// Entity header banner.
///
/// [EntityBannerLayout.photo] fills the banner with the picture itself.
/// Artist uses it on compact, tablet, and wide.
/// [EntityBannerLayout.cover] paints a flat field from the cover's dominant
/// color and puts the cover on the left. Album, playlist, podcast, episode,
/// and profile use it on tablet and wide.
/// [EntityBannerLayout.centered] is the compact header for those same
/// entities: blurred cover wash, centered 140 cover, title and meta below.
/// Actions stay in the body on compact.
enum EntityBannerLayout { photo, cover, centered }

class EntityBannerHeader extends ConsumerWidget {
  final EntityBannerLayout layout;
  final String title;
  final String? eyebrow;
  final bool explicit;
  final Widget? meta;
  final String? imageUrl;

  /// Replaces the default cover tile. Local playlists pass a collage.
  /// [imageUrl] is still used to sample the field color on [EntityBannerLayout.cover].
  final Widget? art;

  /// Optional blurred backdrop. When null, the centered wash uses [imageUrl].
  /// Local playlists pass a [PlaylistCoverCollage] here.
  final Widget? background;
  final String? heroTag;
  final EntityBannerArtShape shape;
  final IconData placeholderIcon;
  final double scrollProgress;
  final bool wide;
  final double contentWidth;
  final Widget? actions;

  const EntityBannerHeader({
    super.key,
    this.layout = EntityBannerLayout.cover,
    required this.title,
    this.eyebrow,
    this.explicit = false,
    this.meta,
    this.imageUrl,
    this.art,
    this.background,
    this.heroTag,
    this.shape = EntityBannerArtShape.rounded,
    required this.placeholderIcon,
    required this.scrollProgress,
    required this.wide,
    required this.contentWidth,
    this.actions,
  });

  /// Height passed to [SliverAppBar.expandedHeight].
  ///
  /// Does not include the status-bar inset; [SliverAppBar.primary] adds that.
  static double expandedHeight({
    required bool wide,
    bool hasActions = true,
    EntityBannerLayout layout = EntityBannerLayout.cover,
  }) {
    if (layout == EntityBannerLayout.centered) return 340;
    final actionBlock = hasActions ? 72.0 : 0.0;
    if (layout == EntityBannerLayout.photo) {
      return kToolbarHeight + (wide ? 224.0 : 180.0);
    }
    final art = wide ? 180.0 : 148.0;
    return kToolbarHeight + 20 + art + actionBlock + 12;
  }

  double get _artSize {
    if (layout == EntityBannerLayout.centered) return 140;
    return wide ? 180 : 148;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = PlayerColors.of(context);
    final horizontalPad = entityHorizontalPadding(
      contentWidth,
      shellShortestSide: MediaQuery.sizeOf(context).shortestSide,
    );
    final fade = (1.0 - scrollProgress * 1.5).clamp(0.0, 1.0);

    if (layout == EntityBannerLayout.centered) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _centeredWash(theme),
          const _EntityBannerScrim(stops: [0.0, 0.20, 0.32]),
          Positioned(
            top: MediaQuery.paddingOf(context).top + kToolbarHeight,
            left: horizontalPad,
            right: horizontalPad,
            bottom: 12,
            child: Opacity(
              opacity: fade,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _artwork(theme),
                  const SizedBox(height: 14),
                  _centeredCopy(theme),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (layout == EntityBannerLayout.photo) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Opacity(opacity: fade, child: _photoWash(theme)),
          const _EntityBannerScrim(),
        ],
      );
    }

    final top = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final field = _fieldColor(context, ref, theme);

    return Stack(
      fit: StackFit.expand,
      children: [
        _colorField(field),
        const _EntityBannerScrim(),
        Positioned(
          top: top,
          left: horizontalPad,
          right: horizontalPad,
          bottom: 8,
          child: Opacity(
            opacity: fade,
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: actions != null ? 12 : 0),
                    child: _body(theme, colors),
                  ),
                ),
                ?actions,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _centeredWash(ThemeData theme) {
    final backdrop = background;
    final url = imageUrl;
    final surface = theme.colorScheme.surface;
    final Widget washChild;
    if (backdrop != null) {
      washChild = backdrop;
    } else if (url != null && url.isNotEmpty) {
      washChild = CachedNetworkImage(imageUrl: url, fit: BoxFit.cover);
    } else {
      return ColoredBox(color: surface);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Opacity(opacity: 0.4, child: washChild),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                surface.withValues(alpha: 0.55),
                surface.withValues(alpha: 0.88),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _fieldColor(BuildContext context, WidgetRef ref, ThemeData theme) {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return theme.colorScheme.surfaceContainer;
    }
    final palette = ref.watch(
      paletteNotifierProvider.select((map) => map[url]),
    );
    if (palette == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(paletteNotifierProvider.notifier).extractPalette(url, url);
      });
      return theme.colorScheme.surfaceContainer;
    }
    return _bannerFieldColor(palette.dominantColor);
  }

  Widget _body(ThemeData theme, PlayerColors colors) {
    final copy = _copy(theme, colors);
    if (layout == EntityBannerLayout.photo) {
      return Align(alignment: Alignment.bottomLeft, child: copy);
    }
    return Row(
      children: [
        _artwork(theme),
        const SizedBox(width: 28),
        Expanded(child: copy),
      ],
    );
  }

  Widget _photoWash(ThemeData theme) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return ColoredBox(color: theme.colorScheme.surfaceContainer);
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.2),
    );
  }

  Widget _colorField(Color field) {
    final deep = HSLColor.fromColor(field)
        .withLightness(
          (HSLColor.fromColor(field).lightness * 0.62).clamp(0.10, 0.24),
        )
        .toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [field, deep],
        ),
      ),
    );
  }

  Widget _centeredCopy(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            children: [
              if (explicit)
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: ExplicitBadge(),
                  ),
                ),
              TextSpan(text: title),
            ],
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (meta != null) ...[const SizedBox(height: 4), meta!],
      ],
    );
  }

  Widget _copy(ThemeData theme, PlayerColors colors) {
    final textShadows = [
      Shadow(
        color: theme.colorScheme.scrim.withValues(alpha: 0.55),
        blurRadius: 10,
        offset: const Offset(0, 1),
      ),
    ];
    final titleStyle =
        (wide ? theme.textTheme.displayMedium : theme.textTheme.displaySmall)
            ?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.titlePrimary,
              height: 1.02,
              shadows: textShadows,
            );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.titleSecondary,
              shadows: textShadows,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
        ],
        Text.rich(
          TextSpan(
            children: [
              if (explicit)
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: ExplicitBadge(),
                  ),
                ),
              TextSpan(text: title),
            ],
          ),
          style: titleStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (meta != null) ...[const SizedBox(height: 12), meta!],
      ],
    );
  }

  Widget _artwork(ThemeData theme) {
    final radius = shape == EntityBannerArtShape.circle
        ? null
        : BorderRadius.circular(SonoraPulseTokens.radiusMedia);
    final child = art ?? _defaultArt(theme);
    final isCentered = layout == EntityBannerLayout.centered;
    final shadowBlur = isCentered ? 16.0 : 18.0;
    final shadowOffset = isCentered ? const Offset(0, 6) : const Offset(0, 8);

    final framed = Container(
      width: _artSize,
      height: _artSize,
      decoration: BoxDecoration(
        shape: shape == EntityBannerArtShape.circle
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: shadowBlur,
            offset: shadowOffset,
          ),
        ],
      ),
      child: shape == EntityBannerArtShape.circle
          ? ClipOval(child: child)
          : ClipRRect(borderRadius: radius!, child: child),
    );

    final tag = heroTag;
    if (tag == null) return framed;
    return Hero(tag: tag, child: framed);
  }

  Widget _defaultArt(ThemeData theme) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        width: _artSize,
        height: _artSize,
        errorWidget: (_, _, _) => _placeholder(theme),
      );
    }
    return _placeholder(theme);
  }

  Widget _placeholder(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          placeholderIcon,
          size: layout == EntityBannerLayout.centered ? 60 : 64,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Pins a cover color into the range where white title text stays readable.
Color _bannerFieldColor(Color source) {
  final hsl = HSLColor.fromColor(source);
  final saturation = hsl.saturation < 0.18
      ? 0.28
      : hsl.saturation.clamp(0.28, 0.72);
  final lightness = hsl.lightness.clamp(0.24, 0.40);
  return hsl.withSaturation(saturation).withLightness(lightness).toColor();
}

class _EntityBannerScrim extends StatelessWidget {
  final List<double> stops;

  const _EntityBannerScrim({this.stops = const [0.0, 0.16, 0.28]});

  @override
  Widget build(BuildContext context) {
    final colors = PlayerColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: stops,
          colors: [
            colors.topScrimStart,
            colors.topScrimMid,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

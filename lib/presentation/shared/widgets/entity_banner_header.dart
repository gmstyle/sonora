import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/player_colors.dart';
import '../../../core/theme/sonora_pulse_tokens.dart';
import '../../providers/palette_provider.dart';
import 'entity_wide_body.dart';
import 'explicit_badge.dart';

/// Cover shape for [EntityBannerHeader] when the layout is [EntityBannerLayout.cover].
enum EntityBannerArtShape { circle, rounded }

/// Entity header banner.
///
/// [EntityBannerLayout.photo] fills the banner with the picture itself.
/// Artist uses it on compact, tablet, and wide.
/// [EntityBannerLayout.cover] paints a flat field from the cover's dominant
/// color and puts the cover on the left. Album, playlist, podcast, episode,
/// and profile use it on tablet and wide. Those compact screens keep a
/// centered header.
enum EntityBannerLayout { photo, cover }

class EntityBannerHeader extends ConsumerWidget {
  final EntityBannerLayout layout;
  final String title;
  final String? eyebrow;
  final bool explicit;
  final Widget? meta;
  final String? imageUrl;

  /// Replaces the default cover tile. Local playlists pass a collage.
  /// [imageUrl] is still used to sample the field color.
  final Widget? art;
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
    final actionBlock = hasActions ? 72.0 : 0.0;
    if (layout == EntityBannerLayout.photo) {
      final photo = wide ? 248.0 : 200.0;
      return kToolbarHeight + photo + actionBlock;
    }
    final art = wide ? 180.0 : 148.0;
    return kToolbarHeight + 20 + art + actionBlock + 12;
  }

  double get _artSize => wide ? 180 : 148;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = PlayerColors.of(context);
    final horizontalPad = entityHorizontalPadding(
      contentWidth,
      shellShortestSide: MediaQuery.sizeOf(context).shortestSide,
    );
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight + 12;
    final fade = (1.0 - scrollProgress * 1.5).clamp(0.0, 1.0);
    final field = layout == EntityBannerLayout.cover
        ? _fieldColor(context, ref, theme)
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (layout == EntityBannerLayout.photo)
          _photoWash(theme)
        else
          _colorField(theme, field!),
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
                Expanded(child: _body(theme, colors)),
                ?actions,
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
    final image = imageUrl == null || imageUrl!.isEmpty
        ? ColoredBox(color: theme.colorScheme.surfaceContainer)
        : CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.04),
                Colors.black.withValues(alpha: 0.55),
                theme.colorScheme.surface,
              ],
              stops: const [0.0, 0.42, 0.78, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _colorField(ThemeData theme, Color field) {
    final deep = HSLColor.fromColor(field)
        .withLightness(
          (HSLColor.fromColor(field).lightness * 0.62).clamp(0.10, 0.24),
        )
        .toColor();
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [field, deep],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.surface.withValues(alpha: 0),
                  theme.colorScheme.surface,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _copy(ThemeData theme, PlayerColors colors) {
    final titleStyle =
        (wide ? theme.textTheme.displayMedium : theme.textTheme.displaySmall)
            ?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.titlePrimary,
              height: 1.02,
            );

    return Column(
      mainAxisAlignment: layout == EntityBannerLayout.photo
          ? MainAxisAlignment.end
          : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.titleSecondary,
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
            blurRadius: 18,
            offset: const Offset(0, 8),
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
          size: 64,
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
  const _EntityBannerScrim();

  @override
  Widget build(BuildContext context) {
    final colors = PlayerColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.16, 0.28],
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

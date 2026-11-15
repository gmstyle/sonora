import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../shared/widgets/thumbnail_widget.dart';
import '../providers/tv_spotlight_provider.dart';
import '../tv_metrics.dart';
import '../tv_shell_focus.dart';
import 'tv_focusable.dart';

/// Contextual Hero Spotlight for Android TV Home browser.
///
/// Updates dynamically as the user navigates across shelf items,
/// showing high-impact artwork aura, title, artist metadata, and quick actions.
class TvHeroSpotlight extends ConsumerWidget {
  const TvHeroSpotlight({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotlight = ref.watch(tvSpotlightProvider);
    if (spotlight == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TvMetrics.contentPadding,
        TvMetrics.browseTopPadding,
        TvMetrics.contentPadding,
        20,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: TvMetrics.heroSpotlightHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                TvColors.surface.withValues(alpha: 0.96),
                TvColors.surface.withValues(alpha: 0.80),
                TvColors.surfaceCard.withValues(alpha: 0.55),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TvColors.border),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Dynamic blurred circular background artwork aura bottom-right
              if (spotlight.imageUrl != null)
                Positioned(
                  bottom: -48,
                  right: -36,
                  width: 260,
                  height: 260,
                  child: ClipOval(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                      child: Opacity(
                        opacity: 0.42,
                        child: ThumbnailWidget(
                          imageUrl: spotlight.imageUrl,
                          size: 260,
                          shape: ThumbnailShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),

              // Gradient scrim to ensure high text contrast
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        TvColors.surface.withValues(alpha: 0.96),
                        TvColors.surface.withValues(alpha: 0.72),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.58, 1.0],
                    ),
                  ),
                ),
              ),

              // Foreground content
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (spotlight.tag != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Text(
                                spotlight.tag!.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          Text(
                            spotlight.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: TvColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          if (spotlight.subtitle != null &&
                              spotlight.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              spotlight.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (spotlight.description != null &&
                              spotlight.description!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              spotlight.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: TvColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Quick Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (spotlight.onPlay != null)
                          TvFocusable(
                            onSelect: spotlight.onPlay,
                            onLeftAtEdge: () =>
                                TvShellFocus.requestSidebar(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.28,
                                    ),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
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
                        if (spotlight.onOpen != null) ...[
                          const SizedBox(width: 12),
                          TvFocusable(
                            onSelect: spotlight.onOpen,
                            onLeftAtEdge: spotlight.onPlay == null
                                ? () => TvShellFocus.requestSidebar(context)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: TvColors.surfaceButton.withValues(
                                  alpha: 0.85,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TvColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l10n.showAll,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: TvColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    LucideIcons.chevronRight,
                                    size: 16,
                                    color: TvColors.textPrimary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../features/player/player_sheet.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/action_feedback_listener.dart';
import '../widgets/branch_fade_transition.dart';
import '../widgets/player_error_listener.dart';
import '../widgets/sonora_logo.dart';
import '../widgets/scale_button.dart';
import '../widgets/vinyl_artwork.dart';
import '../../features/player/full_player_content.dart';

final _icons = [
  LucideIcons.home,
  LucideIcons.search,
  LucideIcons.library,
  LucideIcons.download,
  LucideIcons.settings,
];

class WideShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const WideShell({super.key, required this.navigationShell});

  @override
  ConsumerState<WideShell> createState() => _WideShellState();
}

class _WideShellState extends ConsumerState<WideShell> {
  @override
  Widget build(BuildContext context) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final isPlayerActive = ref.watch(playerStateProvider).currentSong != null;
    final colorScheme = Theme.of(context).colorScheme;
    final targetWidth = isCollapsed ? 72.0 : 240.0;

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: targetWidth,
            child: Material(
              color: colorScheme.surfaceContainerLow,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: targetWidth,
                  maxWidth: targetWidth,
                  child: SizedBox(
                    width: targetWidth,
                    child: Column(
                      children: [
                        Container(
                          height: 80,
                          padding: EdgeInsets.symmetric(
                            horizontal: isCollapsed ? 12 : 24,
                          ),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment:
                                isCollapsed
                                    ? MainAxisAlignment.center
                                    : MainAxisAlignment.spaceBetween,
                            children: [
                              if (!isCollapsed) ...[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SonoraLogo.icon(32),
                                    const SizedBox(width: 12),
                                    Text(
                                      'SONORA',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              IconButton(
                                icon: Icon(
                                  isCollapsed
                                      ? LucideIcons.menu
                                      : LucideIcons.chevronLeft,
                                ),
                                onPressed: () {
                                  ref
                                      .read(sidebarCollapsedProvider.notifier)
                                      .toggle();
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              for (var i = 0; i < _icons.length; i++)
                                _buildNavItem(i, context),
                            ],
                          ),
                        ),
                        _SidebarPlayerIndicator(isCollapsed: isCollapsed),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: isPlayerActive ? 72.0 : 0.0),
                  child: BranchFadeTransition(
                    navigationShell: widget.navigationShell,
                  ),
                ),
                const PlayerSheet(),
                const PlayerErrorListener(),
                const ActionFeedbackListener(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int i, BuildContext context) {
    final isCollapsed = ref.watch(sidebarCollapsedProvider);
    final isSelected = widget.navigationShell.currentIndex == i;
    final colorScheme = Theme.of(context).colorScheme;
    final label = _getLabel(AppLocalizations.of(context)!, i);

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Tooltip(
          message: label,
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor:
                    isSelected
                        ? colorScheme.secondaryContainer.withValues(alpha: 0.5)
                        : null,
                foregroundColor:
                    isSelected ? colorScheme.primary : colorScheme.onSurface,
                padding: EdgeInsets.zero,
              ),
              onPressed: () => widget.navigationShell.goBranch(i),
              child: Icon(_icons[i]),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Stack(
        children: [
          ScaleButton(
            onTap: () => widget.navigationShell.goBranch(i),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? colorScheme.secondaryContainer.withValues(alpha: 0.4)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    _icons[i],
                    color:
                        isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color:
                            isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSelected)
            Positioned(
              left: 0,
              top: 14,
              bottom: 14,
              width: 3.5,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _getLabel(AppLocalizations l10n, int index) {
  return [
    l10n.home,
    l10n.search,
    l10n.library,
    l10n.downloads,
    l10n.settingsLabel,
  ][index];
}

class _SidebarPlayerIndicator extends ConsumerWidget {
  final bool isCollapsed;

  const _SidebarPlayerIndicator({required this.isCollapsed});

  void _openFullPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                const FullPlayerContent(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final currentSong = playerState.currentSong;

    if (currentSong == null) return const SizedBox.shrink();

    final vinylWidget = VinylArtwork(
      imageUrl: currentSong.artUri?.toString(),
      size: isCollapsed ? 44 : 52,
      isPlaying: playerState.isPlaying,
      onTap: () => _openFullPlayer(context),
      tooltipMessage:
          isCollapsed
              ? '${currentSong.title} - ${currentSong.artist ?? ''}'
              : 'Apri lettore',
    );

    return IgnorePointer(
      ignoring: isCollapsed,
      child: AnimatedOpacity(
        opacity: isCollapsed ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: AnimatedAlign(
          alignment: Alignment.topCenter,
          heightFactor: isCollapsed ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: AnimatedSlide(
            offset: isCollapsed ? const Offset(0.2, 0.0) : Offset.zero,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: 196,
                    child: Row(
                      children: [
                        vinylWidget,
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _openFullPlayer(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentSong.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentSong.artist ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _MiniWaveform(isPlaying: playerState.isPlaying),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniWaveform extends StatefulWidget {
  final bool isPlaying;

  const _MiniWaveform({required this.isPlaying});

  @override
  State<_MiniWaveform> createState() => _MiniWaveformState();
}

class _MiniWaveformState extends State<_MiniWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _MiniWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: 16,
          width: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (index) {
              double factor;
              if (widget.isPlaying) {
                final value = _controller.value;
                final radians = value * 2 * math.pi;
                if (index == 0) {
                  factor = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(radians * 2));
                } else if (index == 1) {
                  factor =
                      0.3 + 0.7 * (0.5 + 0.5 * math.sin(radians * 1.5 + 1.0));
                } else {
                  factor =
                      0.3 + 0.7 * (0.5 + 0.5 * math.sin(radians * 2.5 + 2.0));
                }
              } else {
                factor = 0.25;
              }

              factor = factor.clamp(0.25, 1.0);

              return Container(
                width: 3,
                height: 16 * factor,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

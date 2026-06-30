import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../providers/connectivity_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';

class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key});

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  bool _wasOffline = false;
  bool _showBanner = false;
  bool _connectionRestored = false;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<double>(
      begin: -60.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _handleTap(BuildContext context, bool isManualOffline) {
    if (isManualOffline) {
      ref.read(settingsProvider.notifier).setOfflineMode(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.offlineModeDisabled ??
                "Offline mode disabled",
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.noConnectionMessage ??
                "No internet connection. Check your network.",
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(isOfflineProvider);
    final settings = ref.watch(settingsProvider);
    final isManualOffline = settings.offlineMode;

    if (isOffline && !_wasOffline) {
      _wasOffline = true;
      _connectionRestored = false;
      _showBanner = true;
      _dismissTimer?.cancel();
      _controller.forward();
    } else if (!isOffline && _wasOffline) {
      _wasOffline = false;
      _connectionRestored = true;
      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _controller.reverse().then((_) {
            if (mounted) {
              setState(() {
                _showBanner = false;
                _connectionRestored = false;
              });
            }
          });
        }
      });
    }

    if (!_showBanner) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < kCompactBreakpoint;
    final isTablet =
        screenWidth >= kCompactBreakpoint && screenWidth < kExpandedBreakpoint;
    final isWide = screenWidth >= kExpandedBreakpoint;

    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final bgColor =
        _connectionRestored
            ? colorScheme.primary.withValues(alpha: 0.9)
            : (isManualOffline
                ? colorScheme.tertiary.withValues(alpha: 0.9)
                : colorScheme.error.withValues(alpha: 0.9));

    final textColor =
        _connectionRestored
            ? colorScheme.onPrimary
            : (isManualOffline ? colorScheme.onTertiary : colorScheme.onError);

    final icon =
        _connectionRestored
            ? LucideIcons.wifi
            : (isManualOffline ? LucideIcons.wifiOff : LucideIcons.wifiOff);

    // Placement configurations
    double? top;
    double? bottom;
    double? left;
    double? right;

    bool isCollapsedSidebar = false;
    if (isWide) {
      isCollapsedSidebar = ref.watch(sidebarCollapsedProvider);
    }

    if (isMobile) {
      top = MediaQuery.of(context).padding.top + 8;
      right = 16;
    } else if (isTablet) {
      top = MediaQuery.of(context).padding.top + 8;
      right = 24;
    } else {
      bottom = 24;
      if (isCollapsedSidebar) {
        // Center inside the 72px sidebar
        left = 16;
      } else {
        // Place beautifully inside the 240px wide sidebar
        left = 24;
      }
    }

    Widget content;
    if (_connectionRestored) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            l10n?.connectionRestored ?? "Connessione ripristinata",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else if (isMobile || (isWide && isCollapsedSidebar)) {
      // Circle badge for mobile or collapsed wide sidebar
      content = Tooltip(
        message:
            isManualOffline
                ? (l10n?.offlineMode ?? "Offline Mode")
                : (l10n?.offlineNotification ?? "Offline"),
        child: Icon(icon, size: 16, color: textColor),
      );
    } else {
      // Capsule with text for tablet or expanded wide sidebar
      final text =
          isManualOffline
              ? (l10n?.offlineMode ?? "Offline Mode")
              : (l10n?.offlineNotification ?? "Offline");
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    final isRound =
        (isMobile || (isWide && isCollapsedSidebar)) && !_connectionRestored;

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final slideOffset =
              isWide ? -_slideAnimation.value : _slideAnimation.value;
          return Transform.translate(
            offset: Offset(0, slideOffset),
            child: Opacity(opacity: _opacityAnimation.value, child: child),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleTap(context, isManualOffline),
            borderRadius: BorderRadius.circular(32),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: EdgeInsets.symmetric(
                    horizontal: isRound ? 12 : 16,
                    vertical: isRound ? 12 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: textColor.withValues(alpha: 0.2),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

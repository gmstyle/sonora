import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../providers/connectivity_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(isOfflineProvider);

    if (isOffline && !_wasOffline) {
      // Transitioned to offline
      _wasOffline = true;
      _connectionRestored = false;
      _showBanner = true;
      _dismissTimer?.cancel();
      _controller.forward();
    } else if (!isOffline && _wasOffline) {
      // Transitioned back to online
      _wasOffline = false;
      _connectionRestored = true;
      _dismissTimer?.cancel();
      // Show "restored" for 2 seconds, then slide out
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

    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top + 12;

    final bgColor =
        _connectionRestored
            ? Colors.green.withValues(alpha: 0.85)
            : colorScheme.errorContainer.withValues(alpha: 0.85);

    final textColor =
        _connectionRestored ? Colors.white : colorScheme.onErrorContainer;

    final icon = _connectionRestored ? LucideIcons.wifi : LucideIcons.wifiOff;
    final l10n = AppLocalizations.of(context);
    final text =
        _connectionRestored
            ? (l10n?.connectionRestored ?? "Connessione ripristinata")
            : (l10n?.offlineNotification ?? "Sei offline. Brani scaricati");

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(opacity: _opacityAnimation.value, child: child),
          );
        },
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: (_connectionRestored
                            ? Colors.green
                            : colorScheme.error)
                        .withValues(alpha: 0.2),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: textColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

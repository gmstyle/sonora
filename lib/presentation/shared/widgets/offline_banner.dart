import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/connectivity_provider.dart';
import '../../providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';

/// Persistent offline status chip (top-right). Same surface language as
/// [FeedbackToast] / download chip; not a transient toast.
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

  void _handleTap(bool isManualOffline) {
    if (isManualOffline) {
      ref.read(settingsProvider.notifier).setOfflineMode(false);
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final Color mark;
    final String label;
    if (_connectionRestored) {
      mark = colorScheme.primary;
      label = l10n.connectionRestored;
    } else if (isManualOffline) {
      mark = colorScheme.tertiary;
      label = l10n.offlineMode;
    } else {
      mark = colorScheme.error;
      label = l10n.offlineNotification;
    }

    final canTap = isManualOffline && !_connectionRestored;
    final top = MediaQuery.of(context).padding.top + 8;

    return Positioned(
      top: top,
      right: 12,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(opacity: _opacityAnimation.value, child: child),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canTap ? () => _handleTap(isManualOffline) : null,
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: mark,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
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

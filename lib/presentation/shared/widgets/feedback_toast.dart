import 'package:flutter/material.dart';

import '../../providers/action_feedback_provider.dart';

class FeedbackToast {
  static OverlayEntry? _currentEntry;

  FeedbackToast._();

  static void show(
    BuildContext context,
    String message, {
    FeedbackKind kind = FeedbackKind.confirm,
  }) {
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder:
          (_) => _FeedbackToastWidget(
            message: message,
            kind: kind,
            onDismiss: () {
              entry.remove();
              if (_currentEntry == entry) {
                _currentEntry = null;
              }
            },
          ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _FeedbackToastWidget extends StatefulWidget {
  final String message;
  final FeedbackKind kind;
  final VoidCallback onDismiss;

  const _FeedbackToastWidget({
    required this.message,
    required this.kind,
    required this.onDismiss,
  });

  @override
  State<_FeedbackToastWidget> createState() => _FeedbackToastWidgetState();
}

class _FeedbackToastWidgetState extends State<_FeedbackToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  Duration get _holdDuration =>
      widget.kind == FeedbackKind.error
          ? const Duration(seconds: 4)
          : const Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
    );

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween(begin: 0.0, end: 1.0).animate(curve);
    _scale = Tween(begin: 0.85, end: 1.0).animate(curve);

    _controller.forward();

    Future.delayed(_holdDuration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onDismiss();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top + 12;
    final mark =
        widget.kind == FeedbackKind.error
            ? colorScheme.error
            : colorScheme.primary;

    return Positioned(
      top: topPadding,
      left: 24,
      right: 24,
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.outlineVariant),
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
                      Flexible(
                        child: Text(
                          widget.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
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
      ),
    );
  }
}

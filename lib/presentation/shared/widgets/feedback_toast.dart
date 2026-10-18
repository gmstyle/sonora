import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
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
  bool _closing = false;

  bool get _sticky => widget.kind == FeedbackKind.error;

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

    // Confirm toasts auto-dismiss; errors stay until the user closes them.
    if (!_sticky) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _dismiss();
      });
    }
  }

  Future<void> _dismiss() async {
    if (_closing || !mounted) return;
    _closing = true;
    await _controller.reverse();
    if (mounted) {
      widget.onDismiss();
    }
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
    final l10n = AppLocalizations.of(context);
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
                  padding: EdgeInsets.fromLTRB(16, 12, _sticky ? 4 : 16, 12),
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
                          maxLines: _sticky ? 3 : 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.start,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (_sticky) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _dismiss,
                          tooltip: l10n?.close ?? 'Close',
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          icon: Icon(
                            LucideIcons.x,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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

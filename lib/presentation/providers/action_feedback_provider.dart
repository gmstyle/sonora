import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FeedbackKind { confirm, error }

class ActionFeedback {
  final String message;
  final FeedbackKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  const ActionFeedback({
    required this.message,
    this.kind = FeedbackKind.confirm,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });
}

class ActionFeedbackNotifier extends Notifier<ActionFeedback?> {
  @override
  ActionFeedback? build() => null;

  void report(
    String message, {
    FeedbackKind kind = FeedbackKind.confirm,
    String? actionLabel,
    VoidCallback? onAction,
    VoidCallback? onDismiss,
  }) {
    state = ActionFeedback(
      message: message,
      kind: kind,
      actionLabel: actionLabel,
      onAction: onAction,
      onDismiss: onDismiss,
    );
  }

  void clear() => state = null;
}

final actionFeedbackProvider =
    NotifierProvider<ActionFeedbackNotifier, ActionFeedback?>(
      ActionFeedbackNotifier.new,
    );

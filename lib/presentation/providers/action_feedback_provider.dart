import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FeedbackKind { confirm, error }

class ActionFeedback {
  final String message;
  final FeedbackKind kind;

  const ActionFeedback({
    required this.message,
    this.kind = FeedbackKind.confirm,
  });
}

class ActionFeedbackNotifier extends Notifier<ActionFeedback?> {
  @override
  ActionFeedback? build() => null;

  void report(String message, {FeedbackKind kind = FeedbackKind.confirm}) {
    state = ActionFeedback(message: message, kind: kind);
  }

  void clear() => state = null;
}

final actionFeedbackProvider =
    NotifierProvider<ActionFeedbackNotifier, ActionFeedback?>(
      ActionFeedbackNotifier.new,
    );

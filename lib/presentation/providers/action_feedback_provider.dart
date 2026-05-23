import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActionFeedback {
  final String message;

  const ActionFeedback({required this.message});
}

class ActionFeedbackNotifier extends Notifier<ActionFeedback?> {
  @override
  ActionFeedback? build() => null;

  void report(String message) {
    state = ActionFeedback(message: message);
  }

  void clear() => state = null;
}

final actionFeedbackProvider =
    NotifierProvider<ActionFeedbackNotifier, ActionFeedback?>(
  ActionFeedbackNotifier.new,
);

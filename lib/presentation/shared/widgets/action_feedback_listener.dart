import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/action_feedback_provider.dart';
import 'feedback_toast.dart';

class ActionFeedbackListener extends ConsumerStatefulWidget {
  const ActionFeedbackListener({super.key});

  @override
  ConsumerState<ActionFeedbackListener> createState() =>
      _ActionFeedbackListenerState();
}

class _ActionFeedbackListenerState
    extends ConsumerState<ActionFeedbackListener> {
  @override
  Widget build(BuildContext context) {
    ref.listen<ActionFeedback?>(actionFeedbackProvider, (prev, next) {
      if (next != null && prev?.message != next.message) {
        FeedbackToast.show(context, next.message);
        ref.read(actionFeedbackProvider.notifier).clear();
      }
    });
    return const SizedBox.shrink();
  }
}

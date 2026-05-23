import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/action_feedback_provider.dart';

class ActionFeedbackListener extends ConsumerStatefulWidget {
  const ActionFeedbackListener({super.key});

  @override
  ConsumerState<ActionFeedbackListener> createState() =>
      _ActionFeedbackListenerState();
}

class _ActionFeedbackListenerState extends ConsumerState<ActionFeedbackListener> {
  @override
  Widget build(BuildContext context) {
    ref.listen<ActionFeedback?>(actionFeedbackProvider, (prev, next) {
      if (next != null && prev?.message != next.message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
        ref.read(actionFeedbackProvider.notifier).clear();
      }
    });
    return const SizedBox.shrink();
  }
}

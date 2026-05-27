import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/player_provider.dart';
import 'feedback_toast.dart';

class PlayerErrorListener extends ConsumerStatefulWidget {
  const PlayerErrorListener({super.key});

  @override
  ConsumerState<PlayerErrorListener> createState() =>
      _PlayerErrorListenerState();
}

class _PlayerErrorListenerState extends ConsumerState<PlayerErrorListener> {
  @override
  Widget build(BuildContext context) {
    ref.listen(playerStateProvider, (prev, next) {
      if (next.hasError &&
          next.errorMessage != null &&
          prev?.errorMessage != next.errorMessage) {
        FeedbackToast.show(context, next.errorMessage!);
      }
    });
    return const SizedBox.shrink();
  }
}

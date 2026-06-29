import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
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
        String displayMessage = next.errorMessage!;
        final lower = displayMessage.toLowerCase();

        if (lower.contains('offline') ||
            lower.contains('socketexception') ||
            lower.contains('timeout') ||
            lower.contains('network') ||
            lower.contains('connection failed') ||
            lower.contains('handshakeexception') ||
            lower.contains('failed to host') ||
            lower.contains('connection timed out')) {
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            displayMessage = l10n.weakConnectionError;
          }
        }

        FeedbackToast.show(context, displayMessage);
      }
    });
    return const SizedBox.shrink();
  }
}

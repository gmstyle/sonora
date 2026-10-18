import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers/action_feedback_provider.dart';
import '../../providers/player_provider.dart';

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
      if (!next.hasError) return;

      final playError = next.lastPlayError;
      final typedChanged =
          playError != null && prev?.lastPlayError != playError;
      final legacyChanged =
          playError == null &&
          next.errorMessage != null &&
          prev?.errorMessage != next.errorMessage;
      // Engine reported error without a typed/legacy payload (common on Linux
      // when media_kit fails to open the local proxy URL).
      final engineOnlyChanged =
          playError == null &&
          next.errorMessage == null &&
          next.hasError &&
          prev?.hasError != true;

      if (!typedChanged && !legacyChanged && !engineOnlyChanged) return;

      final l10n = AppLocalizations.of(context);
      String displayMessage;

      if (playError != null && l10n != null) {
        displayMessage = switch (playError.kind) {
          PlayErrorKind.rateLimited => l10n.youtubeRateLimitedError,
          PlayErrorKind.network => l10n.weakConnectionError,
          PlayErrorKind.unplayable || PlayErrorKind.unknown =>
            playError.skippedToNext
                ? l10n.trackUnplayableSkipped(playError.title)
                : l10n.trackUnplayable(playError.title),
        };
      } else if (engineOnlyChanged && l10n != null) {
        displayMessage = l10n.weakConnectionError;
      } else {
        displayMessage = next.errorMessage ?? '';
        if (displayMessage.isEmpty) return;
        final lower = displayMessage.toLowerCase();
        if (l10n != null && PlayErrorKind.messageLooksLikeRateLimit(lower)) {
          displayMessage = l10n.youtubeRateLimitedError;
        } else if (l10n != null &&
            (lower.contains('offline') ||
                lower.contains('socketexception') ||
                lower.contains('timeout') ||
                lower.contains('network') ||
                lower.contains('connection failed') ||
                lower.contains('handshakeexception') ||
                lower.contains('failed to host') ||
                lower.contains('connection timed out') ||
                lower.contains('failed to open') ||
                lower.contains('connessione scaduta'))) {
          displayMessage = l10n.weakConnectionError;
        }
      }

      ref
          .read(actionFeedbackProvider.notifier)
          .report(displayMessage, kind: FeedbackKind.error);
    });
    return const SizedBox.shrink();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/app/router.dart';
import '../../presentation/providers/action_feedback_provider.dart';
import '../../presentation/providers/player_provider.dart';
import 'sonora_link.dart';

/// Pure dispatch: play tracks, navigate everything else.
///
/// Extracted for unit tests; production code uses [SonoraLinkHandler.handle].
Future<void> dispatchSonoraLink(
  SonoraLink link, {
  required Future<void> Function(String videoId) playTrack,
  required void Function(String location) navigate,
}) async {
  if (link.kind == SonoraLinkKind.track) {
    await playTrack(link.id);
    return;
  }
  navigate(link.location);
}

/// Applies inbound [SonoraLink]s to the running app (player + GoRouter).
class SonoraLinkHandler {
  SonoraLinkHandler(this._ref);

  final WidgetRef _ref;
  String? _pendingRaw;

  /// Queue a raw URI until the navigator is ready.
  void enqueue(String raw) {
    _pendingRaw = raw;
  }

  /// Process [raw] immediately if the router is ready; otherwise enqueue.
  Future<void> handleRaw(String raw) async {
    final link = parseSonoraLink(raw);
    if (link == null) {
      debugPrint('Ignoring non-Sonora or malformed link: $raw');
      return;
    }

    // Tracks do not need a navigator context; play as soon as the handler runs.
    if (link.kind == SonoraLinkKind.track) {
      await handle(link);
      return;
    }

    if (rootNavigatorKey.currentContext == null) {
      enqueue(raw);
      return;
    }

    await handle(link);
  }

  /// Flush a link that was queued before the navigator existed.
  Future<void> flushPending() async {
    final pending = _pendingRaw;
    if (pending == null) return;
    _pendingRaw = null;
    await handleRaw(pending);
  }

  Future<void> handle(SonoraLink link) async {
    await dispatchSonoraLink(
      link,
      playTrack: (videoId) async {
        try {
          await _ref.read(playerStateProvider.notifier).playVideoId(videoId);
        } catch (e) {
          debugPrint('Deep link play failed: $e');
          _ref
              .read(actionFeedbackProvider.notifier)
              .report('Failed to play: $e', kind: FeedbackKind.error);
        }
      },
      navigate: (location) {
        try {
          _ref.read(routerProvider).go(location);
        } catch (e) {
          debugPrint('Deep link navigate failed: $e');
          enqueue(buildSonoraLink(link));
        }
      },
    );
  }
}

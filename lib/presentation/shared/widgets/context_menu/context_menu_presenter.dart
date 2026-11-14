import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/link/sonora_link.dart';
import '../../../../domain/usecases/player/start_radio_use_case.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/download_provider.dart';
import '../../../providers/player_provider.dart';

/// Present [child] as a wide dialog (≥1200) or a modal bottom sheet.
Future<void> presentContextMenu(BuildContext context, Widget child) {
  if (MediaQuery.of(context).size.width >= kExpandedBreakpoint) {
    return showDialog(
      context: context,
      useRootNavigator: true,
      builder: (_) => Center(
        child: SizedBox(
          width: 360,
          child: Card(elevation: 8, clipBehavior: Clip.hardEdge, child: child),
        ),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    builder: (_) => child,
  );
}

/// Share a Sonora link; on Linux copies to clipboard and shows a toast.
Future<void> shareSonoraLinkFromMenu(
  WidgetRef ref,
  BuildContext context, {
  required SonoraLink link,
  String? title,
  String? subtitle,
}) async {
  final feedback = ref.read(actionFeedbackProvider.notifier);
  final copiedMsg = AppLocalizations.of(context)!.linkCopied;
  final result = await shareSonoraLink(link, title: title, subtitle: subtitle);
  if (result == SonoraShareResult.copied) {
    feedback.report(copiedMsg);
  }
}

/// Whether [context] is already showing the entity identified by [paramKey]/[id]
/// (e.g. `artistId` / `albumId` on the current go_router match).
bool isOnEntityPage(BuildContext context, String paramKey, String id) {
  try {
    return GoRouterState.of(context).pathParameters[paramKey] == id;
  } catch (_) {
    return false;
  }
}

/// Whether an action should appear given [omitActionIds] from a detail header.
bool showAction(Set<String> omitActionIds, String id) =>
    !omitActionIds.contains(id);

/// Close the sheet first, then download using [notifier] captured while mounted.
void enqueueSingleTrackDownload({
  required BuildContext sheetContext,
  required DownloadsNotifier notifier,
  required bool isDownloaded,
  required String videoId,
  required String title,
  required String artist,
  String? artistsJson,
  String? thumbnailUrl,
  bool isExplicit = false,
  bool isVideo = false,
}) {
  final l10n = AppLocalizations.of(sheetContext)!;
  final dialogContext = Navigator.of(sheetContext, rootNavigator: true).context;
  Navigator.pop(sheetContext);

  void start() {
    notifier.startDownload(
      videoId: videoId,
      title: title,
      artist: artist,
      artistsJson: artistsJson,
      thumbnailUrl: thumbnailUrl,
      isExplicit: isExplicit,
      isVideo: isVideo,
    );
  }

  if (!isDownloaded) {
    start();
    return;
  }
  if (!dialogContext.mounted) return;
  showDialog<bool>(
    context: dialogContext,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.alreadyDownloaded),
      content: Text(l10n.alreadyDownloadedConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.continueAction),
        ),
      ],
    ),
  ).then((proceed) {
    if (proceed == true) start();
  });
}

/// Shared song-radio starter used by song and now-playing menus.
Future<void> startSongRadio({
  required String videoId,
  required StartRadioUseCase useCase,
  required PlayerNotifier player,
  required ActionFeedbackNotifier feedback,
  required AppLocalizations l10n,
}) async {
  try {
    final result = await useCase.execute(videoId);
    await player.playNow([result.firstItem]);
    if (result.remaining.isNotEmpty) {
      final pendingItems = useCase.toPendingItems(result.remaining);
      player.addAllToQueue(pendingItems);
    }
  } catch (e) {
    debugPrint('Failed to start radio: $e');
    feedback.report(l10n.failedToStartRadio, kind: FeedbackKind.error);
  }
}

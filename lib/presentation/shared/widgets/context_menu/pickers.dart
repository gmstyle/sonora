import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../domain/models/library_models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../features/library/widgets/create_playlist_dialog.dart';
import '../../../providers/action_feedback_provider.dart';
import '../../../providers/library_notifier.dart';

Future<void> showArtistPicker(
  BuildContext context,
  List<ArtistBasic> artists, {
  required void Function(String artistId) onSelect,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppLocalizations.of(sheetContext)!.goToArtists,
                  style: Theme.of(sheetContext).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const Divider(),
            for (final a in artists)
              ListTile(
                leading: const Icon(LucideIcons.user),
                title: Text(a.name),
                dense: true,
                onTap: () {
                  Navigator.pop(sheetContext);
                  onSelect(a.artistId!);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Playlist picker (shared by song context menu)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showPlaylistPicker(
  BuildContext context,
  WidgetRef ref,
  String videoId, {
  String? title,
  String? artist,
  String? artistsJson,
  String? thumbnailUrl,
  bool isExplicit = false,
  int? duration,
}) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    builder: (_) => PlaylistPickerSheet(
      videoId: videoId,
      title: title,
      artist: artist,
      artistsJson: artistsJson,
      thumbnailUrl: thumbnailUrl,
      isExplicit: isExplicit,
      duration: duration,
    ),
  );
}

class PlaylistPickerSheet extends ConsumerStatefulWidget {
  final String videoId;
  final String? title;
  final String? artist;
  final String? artistsJson;
  final String? thumbnailUrl;
  final bool isExplicit;
  final int? duration;

  const PlaylistPickerSheet({
    super.key,
    required this.videoId,
    this.title,
    this.artist,
    this.artistsJson,
    this.thumbnailUrl,
    this.isExplicit = false,
    this.duration,
  });

  @override
  ConsumerState<PlaylistPickerSheet> createState() =>
      PlaylistPickerSheetState();
}

class PlaylistPickerSheetState extends ConsumerState<PlaylistPickerSheet> {
  late Future<List<LocalPlaylistModel>> _playlistsFuture;

  @override
  void initState() {
    super.initState();
    _playlistsFuture = ref
        .read(libraryNotifierProvider.notifier)
        .getAllPlaylists();
  }

  Future<void> _createAndAdd(String name) async {
    final notifier = ref.read(libraryNotifierProvider.notifier);
    await notifier.createPlaylist(name);
    final playlists = await notifier.getAllPlaylists();
    final created = playlists.firstWhere((p) => p.name == name);
    await notifier.addEntryToPlaylist(
      created.id,
      widget.videoId,
      title: widget.title,
      artist: widget.artist,
      artistsJson: widget.artistsJson,
      thumbnailUrl: widget.thumbnailUrl,
      duration: widget.duration,
      isExplicit: widget.isExplicit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FutureBuilder<List<LocalPlaylistModel>>(
          future: _playlistsFuture,
          builder: (context, AsyncSnapshot<List<LocalPlaylistModel>> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final playlists = snapshot.data ?? [];
            if (playlists.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.addToPlaylist,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(LucideIcons.plus),
                      label: Text(
                        AppLocalizations.of(context)!.createNewPlaylist,
                      ),
                      onPressed: () async {
                        final name = await showDialog<String>(
                          context: context,
                          builder: (_) => const CreatePlaylistDialog(),
                        );
                        if (name != null && name.isNotEmpty) {
                          await _createAndAdd(name);
                          if (context.mounted) {
                            final feedback = ProviderScope.containerOf(context)
                                .read(actionFeedbackProvider.notifier);
                            final message = AppLocalizations.of(context)!
                                .addedTo(name);
                            Navigator.pop(context);
                            feedback.report(message);
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    AppLocalizations.of(context)!.addToPlaylist,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        leading: const Icon(LucideIcons.listVideo),
                        title: Text(playlist.name),
                        onTap: () async {
                          await ref
                              .read(libraryNotifierProvider.notifier)
                              .addEntryToPlaylist(
                                playlist.id,
                                widget.videoId,
                                title: widget.title,
                                artist: widget.artist,
                                artistsJson: widget.artistsJson,
                                thumbnailUrl: widget.thumbnailUrl,
                                duration: widget.duration,
                                isExplicit: widget.isExplicit,
                              );
                          if (context.mounted) {
                            final feedback = ProviderScope.containerOf(context)
                                .read(actionFeedbackProvider.notifier);
                            final message = AppLocalizations.of(context)!
                                .addedToPlaylist(playlist.name);
                            Navigator.pop(context);
                            feedback.report(message);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

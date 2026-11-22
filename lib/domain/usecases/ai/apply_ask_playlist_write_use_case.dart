import '../../models/ask_chat_models.dart';
import '../../repositories/library_repository.dart';

/// Persists explicit user confirmations for Ask Mixes and Playlist Write
/// proposals (Safe Write policy — only invoked after user confirmation).
class ApplyAskPlaylistWriteUseCase {
  ApplyAskPlaylistWriteUseCase(this._library);

  final LibraryRepository _library;

  /// Executes a confirmed [AskPlaylistWriteProposal] and returns the target
  /// local playlist ID.
  Future<int> execute(AskPlaylistWriteProposal proposal) async {
    switch (proposal.operation) {
      case 'remove':
        final playlistId = await _resolveExistingPlaylistId(
          targetId: proposal.targetPlaylistId,
          playlistName: proposal.playlistName,
        );
        if (playlistId == null) {
          throw StateError('Playlist not found: ${proposal.playlistName}');
        }
        for (final track in proposal.tracks) {
          await _library.removeEntry(playlistId, track.videoId);
        }
        return playlistId;

      case 'append':
        var playlistId = await _resolveExistingPlaylistId(
          targetId: proposal.targetPlaylistId,
          playlistName: proposal.playlistName,
        );
        playlistId ??= await _library.createPlaylist(proposal.playlistName);
        final existing = await _library.getPlaylistEntries(playlistId);
        final existingIds = existing.map((e) => e.videoId).toSet();
        var pos = existing.length;
        for (final track in proposal.tracks) {
          if (!existingIds.add(track.videoId)) continue;
          await _library.addEntry(
            playlistId,
            track.videoId,
            pos++,
            title: track.title,
            artist: track.artist,
            artistsJson: track.artistsJson,
            thumbnailUrl: track.thumbnailUrl,
            duration: track.durationSec,
            isVideo: track.isVideo,
            isExplicit: track.isExplicit,
          );
        }
        return playlistId;

      case 'create':
      default:
        final playlistId = await _library.createPlaylist(proposal.playlistName);
        final seen = <String>{};
        var pos = 0;
        for (final track in proposal.tracks) {
          if (!seen.add(track.videoId)) continue;
          await _library.addEntry(
            playlistId,
            track.videoId,
            pos++,
            title: track.title,
            artist: track.artist,
            artistsJson: track.artistsJson,
            thumbnailUrl: track.thumbnailUrl,
            duration: track.durationSec,
            isVideo: track.isVideo,
            isExplicit: track.isExplicit,
          );
        }
        return playlistId;
    }
  }

  /// Saves an [AskMixAttachment] as a permanent local playlist after explicit
  /// user confirmation.
  Future<int> saveMixAsPlaylist(
    AskMixAttachment mix, {
    String? customName,
  }) async {
    final name = (customName?.trim().isNotEmpty ?? false)
        ? customName!.trim()
        : (mix.title.trim().isNotEmpty ? mix.title.trim() : 'Sonora Ask Mix');
    final playlistId = await _library.createPlaylist(
      name,
      description: mix.subtitle,
    );
    final seen = <String>{};
    var pos = 0;
    for (final track in mix.tracks) {
      if (!seen.add(track.videoId)) continue;
      await _library.addEntry(
        playlistId,
        track.videoId,
        pos++,
        title: track.title,
        artist: track.artist,
        artistsJson: track.artistsJson,
        thumbnailUrl: track.thumbnailUrl,
        duration: track.durationSec,
        isVideo: track.isVideo,
        isExplicit: track.isExplicit,
      );
    }
    return playlistId;
  }

  Future<int?> _resolveExistingPlaylistId({
    required int? targetId,
    required String playlistName,
  }) async {
    if (targetId != null) {
      final found = await _library.getPlaylist(targetId);
      if (found != null) return found.id;
    }
    final trimmed = playlistName.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    final all = await _library.getAllPlaylists();
    for (final p in all) {
      if (p.name.trim().toLowerCase() == trimmed) return p.id;
    }
    return null;
  }
}

import 'library_models.dart';

/// Source of a remote playlist pasted into the import dialog.
enum PlaylistImportKind { youtube, spotify }

/// Parsed playlist identity (YouTube list id or Spotify playlist id).
class RemotePlaylistRef {
  final PlaylistImportKind kind;
  final String id;

  const RemotePlaylistRef({required this.kind, required this.id});

  @override
  bool operator ==(Object other) =>
      other is RemotePlaylistRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// One track from a public Spotify playlist (title/artist metadata only).
class SpotifyPlaylistTrack {
  final String title;
  final String subtitle;
  final int? durationMs;
  final bool isExplicit;
  final String? uri;

  const SpotifyPlaylistTrack({
    required this.title,
    required this.subtitle,
    this.durationMs,
    this.isExplicit = false,
    this.uri,
  });

  /// Artist names as shown by Spotify (`"A, B"`), split and trimmed.
  List<String> get artistNames {
    if (subtitle.trim().isEmpty) return const [];
    return subtitle
        .replaceAll('\u00a0', ' ')
        .split(RegExp(r'\s*,\s*'))
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  String get primaryArtist => artistNames.isEmpty ? '' : artistNames.first;
}

/// Metadata + tracks scraped from Spotify's public embed page.
class SpotifyPlaylistSnapshot {
  final String id;
  final String name;
  final List<SpotifyPlaylistTrack> tracks;
  final bool truncated;

  const SpotifyPlaylistSnapshot({
    required this.id,
    required this.name,
    required this.tracks,
    this.truncated = false,
  });
}

/// A YouTube Music search hit used to fill a local playlist entry.
class ImportedTrackCandidate {
  final String videoId;
  final String title;
  final String artist;
  final String? artistsJson;
  final int? durationSec;
  final String? thumbnailUrl;
  final bool isExplicit;

  const ImportedTrackCandidate({
    required this.videoId,
    required this.title,
    required this.artist,
    this.artistsJson,
    this.durationSec,
    this.thumbnailUrl,
    this.isExplicit = false,
  });
}

/// How [YtMusicTrackMatcher.classify] resolved a Spotify track.
enum SpotifyMatchKind { auto, needsReview, none }

/// One search hit with its matcher score (for review ranking).
class ScoredImportCandidate {
  final ImportedTrackCandidate candidate;
  final double score;

  const ScoredImportCandidate({required this.candidate, required this.score});
}

/// Per-track match result before playlist commit.
class SpotifyTrackMatchOutcome {
  final SpotifyMatchKind kind;
  final SpotifyPlaylistTrack track;
  final ImportedTrackCandidate? match;
  final List<ImportedTrackCandidate> reviewCandidates;

  const SpotifyTrackMatchOutcome._({
    required this.kind,
    required this.track,
    this.match,
    this.reviewCandidates = const [],
  });

  factory SpotifyTrackMatchOutcome.auto({
    required SpotifyPlaylistTrack track,
    required ImportedTrackCandidate match,
  }) {
    return SpotifyTrackMatchOutcome._(
      kind: SpotifyMatchKind.auto,
      track: track,
      match: match,
    );
  }

  factory SpotifyTrackMatchOutcome.needsReview({
    required SpotifyPlaylistTrack track,
    required List<ImportedTrackCandidate> candidates,
  }) {
    return SpotifyTrackMatchOutcome._(
      kind: SpotifyMatchKind.needsReview,
      track: track,
      reviewCandidates: candidates,
    );
  }

  factory SpotifyTrackMatchOutcome.none({required SpotifyPlaylistTrack track}) {
    return SpotifyTrackMatchOutcome._(
      kind: SpotifyMatchKind.none,
      track: track,
    );
  }

  bool get isAuto => kind == SpotifyMatchKind.auto;
  bool get needsReview => kind == SpotifyMatchKind.needsReview;
}

/// One Spotify track slot after prepare (auto, pending review, or skipped).
class SpotifyImportSlot {
  final int index;
  final SpotifyPlaylistTrack track;
  final SpotifyMatchKind kind;
  final ImportedTrackCandidate? candidate;
  final List<ImportedTrackCandidate> reviewCandidates;

  const SpotifyImportSlot({
    required this.index,
    required this.track,
    required this.kind,
    this.candidate,
    this.reviewCandidates = const [],
  });

  bool get needsReview => kind == SpotifyMatchKind.needsReview;

  SpotifyImportSlot withCandidate(ImportedTrackCandidate? chosen) {
    return SpotifyImportSlot(
      index: index,
      track: track,
      kind: chosen == null ? SpotifyMatchKind.none : SpotifyMatchKind.auto,
      candidate: chosen,
    );
  }
}

/// Prepared Spotify→YTM matching plan awaiting optional user review + commit.
class SpotifyImportPlan {
  final SpotifyPlaylistSnapshot snapshot;
  final List<SpotifyImportSlot> slots;

  const SpotifyImportPlan({required this.snapshot, required this.slots});

  List<SpotifyImportSlot> get ambiguous =>
      slots.where((s) => s.needsReview).toList(growable: false);

  int get noneCount =>
      slots.where((s) => s.kind == SpotifyMatchKind.none).length;
}

/// Prepared Spotify sync awaiting optional review before replacing entries.
class SpotifyRefreshPlan {
  final LocalPlaylistModel playlist;
  final SpotifyPlaylistSnapshot snapshot;
  final List<PlaylistEntryModel> currentEntries;
  final List<SpotifyImportSlot> slots;

  const SpotifyRefreshPlan({
    required this.playlist,
    required this.snapshot,
    required this.currentEntries,
    required this.slots,
  });

  List<SpotifyImportSlot> get ambiguous =>
      slots.where((s) => s.needsReview).toList(growable: false);

  int get noneCount =>
      slots.where((s) => s.kind == SpotifyMatchKind.none).length;

  int get localPlaylistId => playlist.id;
}

/// Outcome of importing a remote playlist into the local library.
class PlaylistImportResult {
  final int localPlaylistId;
  final String name;
  final PlaylistImportKind source;
  final int importedCount;
  final int skippedCount;

  const PlaylistImportResult({
    required this.localPlaylistId,
    required this.name,
    required this.source,
    required this.importedCount,
    required this.skippedCount,
  });

  int get totalCount => importedCount + skippedCount;
}

/// Thrown when importing a remote playlist that is already linked locally.
class PlaylistAlreadyLinkedException implements Exception {
  final int localPlaylistId;
  final String name;
  final PlaylistImportKind source;
  final String remoteId;

  const PlaylistAlreadyLinkedException({
    required this.localPlaylistId,
    required this.name,
    required this.source,
    required this.remoteId,
  });

  @override
  String toString() =>
      'PlaylistAlreadyLinkedException($source:$remoteId → #$localPlaylistId $name)';
}

/// Spotify's public embed CDN often returns oscillating stale snapshots.
/// Sync aborts instead of applying an unstable track list.
class SpotifyEmbedUnstableException implements Exception {
  @override
  String toString() =>
      'Spotify playlist data is still updating. Try sync again in a few seconds.';
}

/// Outcome of a manual pull-sync for a linked playlist.
class PlaylistSyncResult {
  final int localPlaylistId;
  final String name;
  final int added;
  final int removed;
  final bool reordered;
  final int skipped;
  final bool nameUpdated;

  const PlaylistSyncResult({
    required this.localPlaylistId,
    required this.name,
    required this.added,
    required this.removed,
    required this.reordered,
    required this.skipped,
    this.nameUpdated = false,
  });

  bool get hadChanges =>
      added > 0 || removed > 0 || reordered || skipped > 0 || nameUpdated;
}

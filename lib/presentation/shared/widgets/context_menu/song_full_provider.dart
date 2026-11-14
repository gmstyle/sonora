import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/music_repository_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Song data provider (lazy enrichment for context menu)
// ─────────────────────────────────────────────────────────────────────────────
// TODO: remove once all LikedSongModel rows in the local DB have
// non-null artistId/albumId (enrichment backfill completed).

final songFullProvider = FutureProvider.family<SongFull, String>((
  ref,
  videoId,
) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getSong(videoId);
});

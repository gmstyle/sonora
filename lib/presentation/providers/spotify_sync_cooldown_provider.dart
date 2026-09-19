import '../../domain/models/library_models.dart';

/// Minimum wait between successful Spotify playlist syncs (and after import).
///
/// The public embed CDN lags the Spotify app by hours; rate-limiting avoids
/// pulling stale snapshots. YouTube-linked playlists are unaffected.
const kSpotifySyncCooldown = Duration(hours: 12);

/// Remaining cooldown for a Spotify-linked [playlist], or `null` if sync is
/// allowed. Anchored on [LocalPlaylistModel.lastSyncedAt] (fallback
/// [LocalPlaylistModel.createdAt]).
Duration? spotifySyncRemaining(LocalPlaylistModel playlist, [DateTime? now]) {
  if (playlist.sourceKind != 'spotify') return null;
  final anchor = playlist.lastSyncedAt ?? playlist.createdAt;
  final left = anchor
      .add(kSpotifySyncCooldown)
      .difference(now ?? DateTime.now());
  if (left <= Duration.zero) return null;
  return left;
}

bool isSpotifySyncCoolingDown(LocalPlaylistModel playlist, [DateTime? now]) =>
    spotifySyncRemaining(playlist, now) != null;

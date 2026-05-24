import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/music_repository_provider.dart';

final artistProvider = FutureProvider.family<ArtistFull, String>((
  ref,
  artistId,
) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getArtist(artistId);
});

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/music_repository_provider.dart';

final albumProvider = FutureProvider.family<AlbumFull, String>((
  ref,
  albumId,
) async {
  final repo = ref.watch(musicRepositoryProvider);
  final resolvedId = await repo.resolveAlbumId(albumId);
  return repo.getAlbum(resolvedId);
});

import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/music_repository_provider.dart';

final browseSectionProvider = FutureProvider.family<
  BrowseHomeResult,
  ({String browseId, String? params})
>((ref, arg) {
  final repo = ref.watch(musicRepositoryProvider);
  return repo.getHome(browseId: arg.browseId, params: arg.params);
});

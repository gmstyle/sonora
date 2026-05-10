import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../domain/repositories/music_repository.dart';
import 'ytmusic_provider.dart';
import 'stream_datasource_provider.dart';

final musicRepositoryProvider = Provider<MusicRepository>((ref) {
  final ytmusic = ref.watch(ytmusicDatasourceProvider);
  final stream = ref.watch(streamDatasourceProvider);
  return MusicRepositoryImpl(ytmusic, stream);
});

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/download/start_download_use_case.dart';
import 'library_repository_provider.dart';
import 'stream_datasource_provider.dart';

final startDownloadUseCaseProvider = Provider<StartDownloadUseCase>((ref) {
  return StartDownloadUseCase(
    ref.watch(streamDatasourceProvider),
    Dio(),
    ref.watch(libraryRepositoryProvider),
  );
});

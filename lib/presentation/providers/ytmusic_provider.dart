import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/ytmusic_datasource.dart';

final ytmusicDatasourceProvider = Provider<YtmusicDatasource>((ref) {
  return YtmusicDatasource();
});

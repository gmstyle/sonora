import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/stream_datasource.dart';

final streamDatasourceProvider = Provider<StreamDatasource>((ref) {
  final ds = StreamDatasource();
  ref.onDispose(ds.dispose);
  return ds;
});

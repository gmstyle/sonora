import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/database_connection.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = createAppDatabase();
  ref.onDispose(db.close);
  return db;
});

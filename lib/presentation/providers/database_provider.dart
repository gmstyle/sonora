import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.create();
  ref.onDispose(db.close);
  return db;
});

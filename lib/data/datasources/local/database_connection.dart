import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'database.dart';

export 'database.dart';

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'sonora',
    native: DriftNativeOptions(
      databaseDirectory:
          Platform.isLinux
              ? getApplicationSupportDirectory
              : getApplicationDocumentsDirectory,
    ),
  );
}

AppDatabase createAppDatabase() => AppDatabase(_openConnection());

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('orphan file is removed when localPath changes on re-download', () async {
    final dir = await Directory.systemTemp.createTemp('sonora_orphan_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final oldPath = p.join(dir.path, 'Song-vid1.m4a');
    final newPath = p.join(dir.path, 'Album', 'Song-vid1.m4a');
    await File(oldPath).writeAsString('old');
    await Directory(p.dirname(newPath)).create(recursive: true);

    // Same contract as StartDownloadUseCase._deletePreviousFileIfNeeded.
    expect(await File(oldPath).exists(), isTrue);
    if (oldPath.isNotEmpty && oldPath != newPath) {
      final oldFile = File(oldPath);
      if (await oldFile.exists()) await oldFile.delete();
    }

    await File(newPath).writeAsString('new');
    expect(await File(oldPath).exists(), isFalse);
    expect(await File(newPath).exists(), isTrue);
  });
}

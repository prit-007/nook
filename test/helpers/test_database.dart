import 'dart:io';

import 'package:drift/native.dart';
import 'package:nook/data/database.dart';
import 'package:path/path.dart' as p;

/// Isolated temporary-file [AppDatabase] harness that cleans up on [dispose].
class TempTestDatabase {
  TempTestDatabase({
    required this.db,
    required this.dir,
    required this.file,
  });

  final AppDatabase db;
  final Directory dir;
  final File file;

  Future<void> dispose() async {
    await db.close();
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }
}

/// Opens a fresh file-backed [AppDatabase] in a temporary directory.
Future<TempTestDatabase> createTempFileTestDatabase({
  String prefix = 'nook_test_db_',
}) async {
  final dir = await Directory.systemTemp.createTemp(prefix);
  final file = File(p.join(dir.path, 'test_notes.db'));
  final db = AppDatabase(NativeDatabase(file));
  await db.customStatement('SELECT 1;');
  return TempTestDatabase(db: db, dir: dir, file: file);
}

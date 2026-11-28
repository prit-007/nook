import 'dart:io';

import 'package:drift/native.dart';
import 'package:nook/data/database.dart';
import 'package:path/path.dart' as p;

/// Builds synthetic legacy fixture SQLite databases for migration testing.
Future<File> createLegacyFixtureDb(
  Directory dir, {
  required int fromVersion,
}) async {
  assert(fromVersion >= 8 && fromVersion <= 10);
  final file = File(p.join(dir.path, 'fixture_v$fromVersion.db'));
  final db = AppDatabase(NativeDatabase(file));
  await db.customStatement('SELECT 1;');

  // Seed a notebook and a note before downgrading columns to match legacy schema.
  await db.customStatement(
    "INSERT INTO notebooks (id, name, color_seed, created_at) VALUES ('nb-legacy-1', 'Legacy Notebook', '#4CAF50', 1700000000);",
  );
  await db.customStatement(
    'INSERT INTO notes (id, title, type, plain_text, device_origin_id, notebook_id, created_at, updated_at) '
    "VALUES ('note-legacy-1', 'Legacy Note', 'text', 'Preserved across upgrade', 'dev-legacy', 'nb-legacy-1', 1700000000, 1700000000);",
  );

  if (fromVersion < 12) {
    await db.customStatement('ALTER TABLE note_tags DROP COLUMN deleted;');
    await db.customStatement('ALTER TABLE note_tags DROP COLUMN deleted_at;');
    await db.customStatement('ALTER TABLE notes DROP COLUMN hlc;');
    await db.customStatement('ALTER TABLE notebooks DROP COLUMN hlc;');
  }
  if (fromVersion < 11) {
    await db.customStatement('ALTER TABLE notebooks DROP COLUMN parent_id;');
  }
  if (fromVersion < 10) {
    await db.customStatement('ALTER TABLE notes DROP COLUMN archived;');
  }
  if (fromVersion < 9) {
    await db.customStatement('ALTER TABLE notes DROP COLUMN font_style;');
  }

  await db.customStatement('PRAGMA user_version = $fromVersion;');
  await db.close();
  return file;
}

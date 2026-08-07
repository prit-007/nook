import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import 'tables/notebooks.dart';
import 'tables/notes.dart';
import 'tables/checklist_items.dart';
import 'tables/attachments.dart';
import 'tables/tags.dart';
import 'tables/note_tags.dart';
import 'tables/sync_log.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Notebooks,
  Notes,
  ChecklistItems,
  Attachments,
  Tags,
  NoteTags,
  SyncLog,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE VIRTUAL TABLE notes_fts USING fts5(id UNINDEXED, title, plainText)',
          );
        },
      );
}

/// Opens an in-memory database for testing.
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

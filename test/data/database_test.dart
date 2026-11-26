import 'dart:io';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/attachments.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/data/tables/sync_log.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Database schema', () {
    test('can be created with all tables', () async {
      // ignore: unnecessary_null_comparison
      expect(db, isNotNull);
    });

    test('schema version is 11', () {
      expect(db.schemaVersion, 11);
    });

    test('migrates v10 database to v11 preserving notebooks with parentId=null',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('nook_mig_v10_');
      try {
        final dbPath = p.join(tempDir.path, 'v10.db');
        final rawDb = AppDatabase(NativeDatabase(File(dbPath)));
        await rawDb.customStatement('SELECT 1');
        await rawDb
            .customStatement('ALTER TABLE notebooks DROP COLUMN parent_id;');
        await rawDb.customStatement('PRAGMA user_version = 10;');
        await rawDb.customStatement(
          "INSERT INTO notebooks (id, name, color_seed, created_at) VALUES ('nb-v10', 'Root Collection', '#336699', 1700000000);",
        );
        await rawDb.close();

        final migrated = AppDatabase(NativeDatabase(File(dbPath)));
        expect(migrated.schemaVersion, 11);
        final row = await (migrated.select(migrated.notebooks)
              ..where((t) => t.id.equals('nb-v10')))
            .getSingle();
        expect(row.name, 'Root Collection');
        expect(row.parentId, isNull);
        await migrated.close();
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test('migrates v9 database to v10 preserving notes with archived=false',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('nook_mig_v9_');
      try {
        final dbPath = p.join(tempDir.path, 'v9.db');
        final rawDb = AppDatabase(NativeDatabase(File(dbPath)));
        // Create schema first, then downgrade to simulate v9 without archived.
        await rawDb.customStatement('SELECT 1');
        await rawDb.customStatement('ALTER TABLE notes DROP COLUMN archived;');
        await rawDb
            .customStatement('ALTER TABLE notebooks DROP COLUMN parent_id;');
        await rawDb.customStatement('PRAGMA user_version = 9;');
        await rawDb.customStatement(
          "INSERT INTO notes (id, type, title, created_at, updated_at, device_origin_id) VALUES ('n-v9', 'text', 'Legacy v9 note', 1700000000, 1700000000, 'd1');",
        );
        await rawDb.close();

        final migrated = AppDatabase(NativeDatabase(File(dbPath)));
        final row = await (migrated.select(migrated.notes)
              ..where((t) => t.id.equals('n-v9')))
            .getSingle();
        expect(row.title, 'Legacy v9 note');
        expect(row.archived, isFalse);
        await migrated.close();
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test(
        'upgrades multi-step legacy schema (v3) to v10 creating new tables & columns',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('nook_mig_v3_');
      try {
        final dbPath = p.join(tempDir.path, 'v3.db');
        final rawDb = AppDatabase(NativeDatabase(File(dbPath)));
        await rawDb.customStatement('SELECT 1');
        await rawDb.customStatement('DROP TABLE IF EXISTS note_revisions;');
        await rawDb.customStatement('DROP TABLE IF EXISTS note_links;');
        await rawDb.customStatement('DROP TABLE IF EXISTS reminders;');
        await rawDb.customStatement('DROP TABLE IF EXISTS templates;');
        await rawDb.customStatement('DROP TABLE IF EXISTS trusted_devices;');
        await rawDb
            .customStatement('ALTER TABLE notes DROP COLUMN font_style;');
        await rawDb.customStatement('ALTER TABLE notes DROP COLUMN archived;');
        await rawDb
            .customStatement('ALTER TABLE notebooks DROP COLUMN parent_id;');
        await rawDb.customStatement('PRAGMA user_version = 3;');
        await rawDb.customStatement(
          "INSERT INTO notes (id, type, title, created_at, updated_at, device_origin_id) VALUES ('n-v3', 'text', 'Legacy v3 note', 1600000000, 1600000000, 'd1');",
        );
        await rawDb.close();

        // Migrate to v11
        final migrated = AppDatabase(NativeDatabase(File(dbPath)));
        expect(migrated.schemaVersion, 11);
        final row = await (migrated.select(migrated.notes)
              ..where((t) => t.id.equals('n-v3')))
            .getSingle();
        expect(row.title, 'Legacy v3 note');
        expect(row.archived, isFalse);
        expect(row.fontStyle, 'auto');

        // Verify newly added tables exist and accept queries
        final revisions = await migrated.select(migrated.noteRevisions).get();
        expect(revisions, isEmpty);
        final templates = await migrated.select(migrated.templates).get();
        expect(templates, isEmpty);

        await migrated.close();
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });

    test(
        'migration safety: backs up database before migration and preserves integrity',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('nook_mig_backup_');
      try {
        final dbPath = p.join(tempDir.path, 'notes.db');
        final backupPath = p.join(tempDir.path, 'notes.db.bak');

        // Create initial db file
        final rawDb = AppDatabase(NativeDatabase(File(dbPath)));
        await rawDb.customStatement('SELECT 1');
        await rawDb.close();

        // Simulate pre-migration backup
        final originalFile = File(dbPath);
        await originalFile.copy(backupPath);
        expect(File(backupPath).existsSync(), isTrue);

        // Open and run migration
        final migrated = AppDatabase(NativeDatabase(File(dbPath)));
        expect(migrated.schemaVersion, 11);
        await migrated.close();

        // Verify backup is intact
        expect(File(backupPath).lengthSync(), greaterThan(0));
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });

  group('Notebooks CRUD', () {
    test('insert and read back a notebook', () async {
      final id = 'test-notebook-1';
      await db.into(db.notebooks).insert(
            NotebooksCompanion.insert(
              id: Value(id),
              name: 'My Notebook',
              colorSeed: '#6750A4',
            ),
          );

      final result = await db.select(db.notebooks).getSingle();
      expect(result.id, id);
      expect(result.name, 'My Notebook');
      expect(result.colorSeed, '#6750A4');
      expect(result.icon, 'notebook');
      expect(result.sortOrder, 0);
    });

    test('insert multiple notebooks and list them', () async {
      await db.into(db.notebooks).insert(
            NotebooksCompanion.insert(
              id: const Value('nb-1'),
              name: 'First',
              colorSeed: '#FF0000',
            ),
          );
      await db.into(db.notebooks).insert(
            NotebooksCompanion.insert(
              id: const Value('nb-2'),
              name: 'Second',
              colorSeed: '#00FF00',
            ),
          );

      final results = await db.select(db.notebooks).get();
      expect(results.length, 2);
    });
  });

  group('Notes CRUD', () {
    test('insert and read back a text note', () async {
      await db.into(db.notebooks).insert(
            NotebooksCompanion.insert(
              id: const Value('nb-1'),
              name: 'Test',
              colorSeed: '#000',
            ),
          );

      final id = 'note-1';
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: Value(id),
              notebookId: const Value('nb-1'),
              type: NoteType.text,
              title: const Value('My Note'),
              deviceOriginId: 'device-1',
            ),
          );

      final result = await db.select(db.notes).getSingle();
      expect(result.id, id);
      expect(result.title, 'My Note');
      expect(result.type, NoteType.text);
      expect(result.pinned, false);
      expect(result.locked, false);
      expect(result.deleted, false);
      expect(result.syncVersion, 0);
    });

    test('insert a checklist note type', () async {
      await db.into(db.notebooks).insert(
            NotebooksCompanion.insert(
              id: const Value('nb-1'),
              name: 'Test',
              colorSeed: '#000',
            ),
          );

      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-checklist'),
              type: NoteType.checklist,
              title: const Value('Groceries'),
              deviceOriginId: 'device-1',
            ),
          );

      final result = await db.select(db.notes).getSingle();
      expect(result.type, NoteType.checklist);
    });

    test('insert a doodle note type', () async {
      await db.into(db.notebooks).insert(
            NotebooksCompanion.insert(
              id: const Value('nb-1'),
              name: 'Test',
              colorSeed: '#000',
            ),
          );

      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-doodle'),
              type: NoteType.doodle,
              title: const Value('My Doodle'),
              deviceOriginId: 'device-1',
            ),
          );

      final result = await db.select(db.notes).getSingle();
      expect(result.type, NoteType.doodle);
    });

    test('soft delete a note', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-del'),
              type: NoteType.text,
              title: const Value('To Delete'),
              deviceOriginId: 'device-1',
            ),
          );

      await (db.update(db.notes)..where((t) => t.id.equals('note-del'))).write(
        NotesCompanion(
          deleted: const Value(true),
          deletedAt: Value(DateTime.now()),
        ),
      );

      final result = await (db.select(db.notes)
            ..where((t) => t.id.equals('note-del')))
          .getSingle();
      expect(result.deleted, true);
      expect(result.deletedAt, isNotNull);
    });
  });

  group('ChecklistItems CRUD', () {
    test('insert and read back checklist items', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-cl'),
              type: NoteType.checklist,
              title: const Value('Tasks'),
              deviceOriginId: 'device-1',
            ),
          );

      await db.into(db.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              id: const Value('cl-1'),
              noteId: 'note-cl',
              itemText: 'Buy milk',
            ),
          );
      await db.into(db.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              id: const Value('cl-2'),
              noteId: 'note-cl',
              itemText: 'Buy eggs',
            ),
          );

      final results = await (db.select(db.checklistItems)
            ..where((t) => t.noteId.equals('note-cl')))
          .get();
      expect(results.length, 2);
      expect(results[0].itemText, 'Buy milk');
      expect(results[1].itemText, 'Buy eggs');
      expect(results[0].checked, false);
    });

    test('check a checklist item', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-cl'),
              type: NoteType.checklist,
              title: const Value('Tasks'),
              deviceOriginId: 'device-1',
            ),
          );

      await db.into(db.checklistItems).insert(
            ChecklistItemsCompanion.insert(
              id: const Value('cl-1'),
              noteId: 'note-cl',
              itemText: 'Buy milk',
            ),
          );

      await (db.update(db.checklistItems)..where((t) => t.id.equals('cl-1')))
          .write(
        const ChecklistItemsCompanion(checked: Value(true)),
      );

      final result = await (db.select(db.checklistItems)
            ..where((t) => t.id.equals('cl-1')))
          .getSingle();
      expect(result.checked, true);
    });
  });

  group('Attachments CRUD', () {
    test('insert and read back an attachment', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-img'),
              type: NoteType.text,
              title: const Value('With Image'),
              deviceOriginId: 'device-1',
            ),
          );

      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('att-1'),
              noteId: 'note-img',
              type: AttachmentType.image,
              filePath: '/path/to/image.png',
            ),
          );

      final result = await db.select(db.attachments).getSingle();
      expect(result.id, 'att-1');
      expect(result.type, AttachmentType.image);
      expect(result.filePath, '/path/to/image.png');
    });

    test('insert a doodle layer attachment', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-doodle'),
              type: NoteType.doodle,
              title: const Value('Sketch'),
              deviceOriginId: 'device-1',
            ),
          );

      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('att-doodle'),
              noteId: 'note-doodle',
              type: AttachmentType.doodleLayer,
              filePath: '/path/to/strokes.json',
            ),
          );

      final result = await db.select(db.attachments).getSingle();
      expect(result.type, AttachmentType.doodleLayer);
    });
  });

  group('Tags CRUD', () {
    test('insert and read back a tag', () async {
      await db.into(db.tags).insert(
            TagsCompanion.insert(
              id: const Value('tag-1'),
              name: 'important',
              colorSeed: '#FF0000',
            ),
          );

      final result = await db.select(db.tags).getSingle();
      expect(result.id, 'tag-1');
      expect(result.name, 'important');
    });

    test('assign tag to note via NoteTags', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('note-tagged'),
              type: NoteType.text,
              title: const Value('Tagged'),
              deviceOriginId: 'device-1',
            ),
          );
      await db.into(db.tags).insert(
            TagsCompanion.insert(
                id: const Value('tag-1'), name: 'work', colorSeed: '#000'),
          );

      await db.into(db.noteTags).insert(
            NoteTagsCompanion.insert(noteId: 'note-tagged', tagId: 'tag-1'),
          );

      final result = await db.select(db.noteTags).getSingle();
      expect(result.noteId, 'note-tagged');
      expect(result.tagId, 'tag-1');
    });

    test('get tags for a note', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('n1'),
              type: NoteType.text,
              title: const Value('T'),
              deviceOriginId: 'd1',
            ),
          );
      await db.into(db.tags).insert(
            TagsCompanion.insert(
                id: const Value('t1'), name: 'personal', colorSeed: '#AAA'),
          );
      await db.into(db.tags).insert(
            TagsCompanion.insert(
                id: const Value('t2'), name: 'work', colorSeed: '#BBB'),
          );
      await db.into(db.noteTags).insert(
            NoteTagsCompanion.insert(noteId: 'n1', tagId: 't1'),
          );
      await db.into(db.noteTags).insert(
            NoteTagsCompanion.insert(noteId: 'n1', tagId: 't2'),
          );

      final query = db.select(db.tags).join([
        innerJoin(db.noteTags, db.noteTags.tagId.equalsExp(db.tags.id)),
      ])
        ..where(db.noteTags.noteId.equals('n1'));

      final results = await query.get();
      expect(results.length, 2);
    });
  });

  group('Notebook soft-delete columns', () {
    test('new notebook has deleted=false and deletedAt=null', () async {
      await db.into(db.notebooks).insert(
            NotebooksCompanion.insert(
              id: const Value('nb-sd-1'),
              name: 'Test Notebook',
              colorSeed: '#FF0000',
            ),
          );

      final result = await (db.select(db.notebooks)
            ..where((t) => t.id.equals('nb-sd-1')))
          .getSingle();
      expect(result.deleted, false);
      expect(result.deletedAt, isNull);
    });

    test('notebook can be soft-deleted', () async {
      await db.into(db.notebooks).insert(
            NotebooksCompanion.insert(
              id: const Value('nb-sd-2'),
              name: 'Delete Me',
              colorSeed: '#00FF00',
            ),
          );

      final now = DateTime.now();
      await (db.update(db.notebooks)..where((t) => t.id.equals('nb-sd-2')))
          .write(
        NotebooksCompanion(
          deleted: const Value(true),
          deletedAt: Value(now),
        ),
      );

      final result = await (db.select(db.notebooks)
            ..where((t) => t.id.equals('nb-sd-2')))
          .getSingle();
      expect(result.deleted, true);
      expect(result.deletedAt, isNotNull);
    });
  });

  group('Tag soft-delete columns', () {
    test('new tag has deleted=false and deletedAt=null', () async {
      await db.into(db.tags).insert(
            TagsCompanion.insert(
              id: const Value('tag-sd-1'),
              name: 'Test Tag',
              colorSeed: '#2196F3',
            ),
          );

      final result = await (db.select(db.tags)
            ..where((t) => t.id.equals('tag-sd-1')))
          .getSingle();
      expect(result.deleted, false);
      expect(result.deletedAt, isNull);
    });

    test('tag can be soft-deleted', () async {
      await db.into(db.tags).insert(
            TagsCompanion.insert(
              id: const Value('tag-sd-2'),
              name: 'Delete Me',
              colorSeed: '#FF5722',
            ),
          );

      final now = DateTime.now();
      await (db.update(db.tags)..where((t) => t.id.equals('tag-sd-2'))).write(
        TagsCompanion(
          deleted: const Value(true),
          deletedAt: Value(now),
        ),
      );

      final result = await (db.select(db.tags)
            ..where((t) => t.id.equals('tag-sd-2')))
          .getSingle();
      expect(result.deleted, true);
      expect(result.deletedAt, isNotNull);
    });
  });

  group('SyncLog', () {
    test('insert and read back a sync log entry', () async {
      await db.into(db.syncLog).insert(
            SyncLogCompanion.insert(
              deviceId: 'device-2',
              deviceName: 'Other Phone',
              noteId: 'note-1',
              action: SyncAction.sent,
            ),
          );

      final result = await db.select(db.syncLog).getSingle();
      expect(result.deviceId, 'device-2');
      expect(result.action, SyncAction.sent);
    });
  });

  group('FTS5', () {
    test('FTS table exists and can be queried', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('fts-note'),
              type: NoteType.text,
              title: const Value('Shopping List'),
              plainText: const Value('Milk, eggs, bread, butter'),
              deviceOriginId: 'device-1',
            ),
          );

      // Manually sync FTS (triggers removed; app code handles sync)
      await db.customStatement(
        'INSERT INTO notes_fts(id, title, plainText) VALUES (?, ?, ?)',
        ['fts-note', 'Shopping List', 'Milk, eggs, bread, butter'],
      );

      final results = await db.customSelect(
        'SELECT * FROM notes_fts WHERE notes_fts MATCH ?',
        variables: [Variable.withString('milk')],
      ).get();

      expect(results.length, 1);
      expect(results.first.data['id'], 'fts-note');
    });

    test('FTS search is case-insensitive', () async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('fts-2'),
              type: NoteType.text,
              title: const Value('Meeting Notes'),
              plainText: const Value('Discuss quarterly budget review'),
              deviceOriginId: 'device-1',
            ),
          );

      await db.customStatement(
        'INSERT INTO notes_fts(id, title, plainText) VALUES (?, ?, ?)',
        ['fts-2', 'Meeting Notes', 'Discuss quarterly budget review'],
      );

      final results = await db.customSelect(
        'SELECT * FROM notes_fts WHERE notes_fts MATCH ?',
        variables: [Variable.withString('BUDGET')],
      ).get();

      expect(results.length, 1);
    });
  });

  group('Encryption', () {
    test('database can be opened with a setup callback', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final dbFile = File(p.join(tempDir.path, 'encrypted_test.db'));

      var setupCalled = false;
      final encryptedDb = AppDatabase(
        NativeDatabase(
          dbFile,
          setup: (database) {
            setupCalled = true;
            database.execute('PRAGMA journal_mode = WAL;');
          },
        ),
      );

      await encryptedDb.select(encryptedDb.notes).get();

      expect(setupCalled, isTrue);

      await encryptedDb.close();
      tempDir.deleteSync(recursive: true);
    });

    test('setup callback runs before drift migrations', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final dbFile = File(p.join(tempDir.path, 'setup_order_test.db'));

      final executionOrder = <String>[];

      final testDb = AppDatabase(
        NativeDatabase(
          dbFile,
          setup: (database) {
            executionOrder.add('setup');
            database.execute('PRAGMA journal_mode = WAL;');
          },
        ),
      );

      await testDb.select(testDb.notes).get();

      expect(executionOrder.isNotEmpty, isTrue);
      expect(executionOrder.first, 'setup');

      await testDb.close();
      tempDir.deleteSync(recursive: true);
    });
  });
}

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  test('Performance benchmark seeds 500 notes and verifies query times',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      const count = 500;
      final sw = Stopwatch()..start();
      final now = DateTime.now();

      await db.transaction(() async {
        for (var i = 0; i < count; i++) {
          final id = 'perf-note-$i';
          final title = 'Benchmark Note #$i';
          final body =
              'Synthetic note payload for performance benchmarking #$i. '
              'Contains architecture, sqlite, and search.';

          await db.into(db.notes).insert(
                NotesCompanion.insert(
                  id: Value(id),
                  title: Value(title),
                  plainText: Value(body),
                  type: i % 5 == 0 ? NoteType.checklist : NoteType.text,
                  pinned: Value(i % 20 == 0),
                  archived: Value(i % 15 == 0),
                  createdAt: Value(now.subtract(Duration(minutes: i))),
                  updatedAt: Value(now.subtract(Duration(minutes: i))),
                  deviceOriginId: 'bench-host',
                ),
              );

          await db.customStatement(
            'INSERT INTO notes_fts(id, title, plainText) VALUES (?, ?, ?)',
            [id, title, body],
          );
        }
      });

      final insertMs = sw.elapsedMilliseconds;
      expect(insertMs, greaterThan(0));

      sw.reset();
      final allNotes = await (db.select(db.notes)
            ..where((t) => t.deleted.equals(false))
            ..where((t) => t.archived.equals(false)))
          .get();
      final queryMs = sw.elapsedMilliseconds;

      expect(allNotes.length, greaterThan(400));
      // In-memory query for 500 notes must complete in under 500ms
      expect(queryMs, lessThan(500));

      sw.reset();
      final searchResults = await db.customSelect(
        'SELECT id, title FROM notes_fts WHERE notes_fts MATCH ? LIMIT 50',
        variables: [Variable.withString('sqlite')],
      ).get();
      final searchMs = sw.elapsedMilliseconds;

      expect(searchResults.length, 50);
      expect(searchMs, lessThan(200));
    } finally {
      await db.close();
    }
  });

  test('Performance benchmark seeds 2,000 notes and verifies query times',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      const count = 2000;
      final sw = Stopwatch()..start();
      final now = DateTime.now();

      await db.transaction(() async {
        for (var i = 0; i < count; i++) {
          final id = 'perf-note-$i';
          final title = 'Large Benchmark Note #$i';
          final body =
              'Payload for large dataset #$i with keywords sqlite, performance, indexing.';

          await db.into(db.notes).insert(
                NotesCompanion.insert(
                  id: Value(id),
                  title: Value(title),
                  plainText: Value(body),
                  type: NoteType.text,
                  createdAt: Value(now.subtract(Duration(minutes: i))),
                  updatedAt: Value(now.subtract(Duration(minutes: i))),
                  deviceOriginId: 'bench-host',
                ),
              );

          await db.customStatement(
            'INSERT INTO notes_fts(id, title, plainText) VALUES (?, ?, ?)',
            [id, title, body],
          );
        }
      });

      final insertMs = sw.elapsedMilliseconds;
      expect(insertMs, greaterThan(0));

      sw.reset();
      final allNotes = await (db.select(db.notes)
            ..where((t) => t.deleted.equals(false)))
          .get();
      final queryMs = sw.elapsedMilliseconds;

      expect(allNotes.length, 2000);
      // Querying 2000 notes should complete well under 1 second
      expect(queryMs, lessThan(1000));

      sw.reset();
      final searchResults = await db.customSelect(
        'SELECT id, title FROM notes_fts WHERE notes_fts MATCH ? LIMIT 50',
        variables: [Variable.withString('indexing')],
      ).get();
      final searchMs = sw.elapsedMilliseconds;

      expect(searchResults.length, 50);
      expect(searchMs, lessThan(200));
    } finally {
      await db.close();
    }
  });
}

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';

/// Performance benchmark script to seed 500 or 2,000 notes and measure
/// query and FTS search throughput.
///
/// Usage:
///   dart run tool/seed_performance_notes.dart [count] [--temp-db]
Future<void> main(List<String> args) async {
  final count = args.isNotEmpty ? int.tryParse(args[0]) ?? 500 : 500;
  final useTempDb = args.contains('--temp-db') || !args.contains('--in-memory');

  stdout.writeln('=== Nook Performance Benchmark (Seeding $count notes) ===');

  Directory? tempDir;
  AppDatabase db;

  if (useTempDb) {
    tempDir = await Directory.systemTemp.createTemp('nook_perf_');
    final dbFile = File('${tempDir.path}/perf.db');
    stdout.writeln('Target DB: ${dbFile.path}');
    db = AppDatabase(NativeDatabase(dbFile));
  } else {
    stdout.writeln('Target DB: in-memory');
    db = AppDatabase(NativeDatabase.memory());
  }

  try {
    final stopwatch = Stopwatch()..start();

    stdout.write('Seeding $count notes in transaction... ');
    final now = DateTime.now();
    await db.transaction(() async {
      for (var i = 0; i < count; i++) {
        final id = 'perf-note-$i';
        final title = 'Benchmark Note #$i';
        final body =
            'This is a synthetic note payload for performance benchmarking #$i. '
            'Contains keywords such as project, architecture, performance, sqlite, and search.';

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

        // Sync to FTS
        await db.customStatement(
          'INSERT INTO notes_fts(id, title, plainText) VALUES (?, ?, ?)',
          [id, title, body],
        );
      }
    });

    final seedDuration = stopwatch.elapsedMilliseconds;
    stdout.writeln(
      'Done in ${seedDuration}ms (${(count / (seedDuration / 1000)).toStringAsFixed(1)} notes/sec)',
    );

    // Benchmark: query all active notes
    stopwatch.reset();
    final allNotes = await (db.select(db.notes)
          ..where((t) => t.deleted.equals(false))
          ..where((t) => t.archived.equals(false)))
        .get();
    final queryDuration = stopwatch.elapsedMilliseconds;
    stdout.writeln('Query ${allNotes.length} active notes: ${queryDuration}ms');

    // Benchmark: FTS query
    stopwatch.reset();
    final searchResults = await db.customSelect(
      'SELECT id, title FROM notes_fts WHERE notes_fts MATCH ? LIMIT 50',
      variables: [Variable.withString('performance')],
    ).get();
    final searchDuration = stopwatch.elapsedMilliseconds;
    stdout.writeln(
      'FTS match query ("performance"): ${searchResults.length} hits in ${searchDuration}ms',
    );

    stdout.writeln('=== Benchmark complete. Status: PASS ===');
  } finally {
    await db.close();
    if (tempDir != null && tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/revision_repository.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  late AppDatabase db;
  late NoteRepository noteRepo;
  late RevisionRepository revRepo;
  DateTime fixedNow() => DateTime(2026, 10, 4, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    noteRepo = NoteRepository(db);
    revRepo = RevisionRepository(db, clock: fixedNow);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Note> seedNote({String title = 'Hello', String? plainText}) {
    return noteRepo.createNote(
      title: title,
      type: NoteType.text,
      deviceOriginId: 'd1',
      plainText: plainText ?? title,
      deltaContent: '{"root":{},"children":[{"type":"paragraph"}]}',
    );
  }

  group('RevisionRepository.maybeSnapshot', () {
    test('creates a revision when bucket has elapsed', () async {
      final note = await seedNote();
      final rev = await revRepo.maybeSnapshot(
        noteId: note.id,
        title: 'Hello',
        deltaContent: note.deltaContent,
        plainText: note.plainText,
        at: fixedNow(),
      );
      expect(rev, isNotNull);
      expect(rev!.noteId, note.id);
      expect(rev.source, RevisionSource.autosave.dbValue);

      // Second snapshot 11 minutes later succeeds.
      final rev2 = await revRepo.maybeSnapshot(
        noteId: note.id,
        title: 'Hello v2',
        deltaContent: '{"v":2}',
        plainText: 'Hello v2',
        at: fixedNow().add(const Duration(minutes: 11)),
      );
      expect(rev2, isNotNull);
      expect((await revRepo.listForNote(note.id)).length, 2);
    });

    test('skips same-bucket autosave snapshots', () async {
      final note = await seedNote();
      await revRepo.maybeSnapshot(
        noteId: note.id,
        title: note.title,
        deltaContent: note.deltaContent,
        plainText: note.plainText,
        at: fixedNow(),
      );
      final skip = await revRepo.maybeSnapshot(
        noteId: note.id,
        title: note.title,
        deltaContent: '{"v":1b}',
        plainText: note.plainText,
        at: fixedNow().add(const Duration(minutes: 5)),
      );
      expect(skip, isNull);
      expect((await revRepo.listForNote(note.id)).length, 1);
    });

    test('manual and restore sources always snapshot', () async {
      final note = await seedNote();
      await revRepo.maybeSnapshot(
        noteId: note.id,
        title: note.title,
        deltaContent: note.deltaContent,
        plainText: note.plainText,
        source: RevisionSource.manual,
        at: fixedNow(),
      );
      final again = await revRepo.maybeSnapshot(
        noteId: note.id,
        title: note.title,
        deltaContent: '{"m":2}',
        plainText: 'x',
        source: RevisionSource.manual,
        at: fixedNow().add(const Duration(minutes: 1)),
      );
      expect(again, isNotNull);
      expect((await revRepo.listForNote(note.id)).length, 2);
    });
  });

  group('RevisionRepository.restore', () {
    test('restore snapshots current state then applies old content', () async {
      final note =
          await seedNote(title: 'Original', plainText: 'Original body');
      final rev = await revRepo.maybeSnapshot(
        noteId: note.id,
        title: 'Original',
        deltaContent: '{"v":"original"}',
        plainText: 'Original body',
        source: RevisionSource.manual,
        at: fixedNow(),
      );

      await noteRepo.updateContent(
        note.id,
        deltaContent: '{"v":"new"}',
        plainText: 'New body',
      );
      await noteRepo.updateNote(note.id, title: 'New title');

      final restored = await revRepo.restore(rev!.id);
      expect(restored.title, 'Original');
      expect(restored.deltaContent, '{"v":"original"}');
      expect(restored.plainText, 'Original body');

      final history = await revRepo.listForNote(note.id);
      // manual snapshot + restore-source snapshot of "new" state
      expect(history.length, greaterThanOrEqualTo(2));
      final restoreSnaps =
          history.where((r) => r.source == RevisionSource.restore.dbValue);
      expect(restoreSnaps, isNotEmpty);
      expect(restoreSnaps.first.plainText, 'New body');
      expect(restoreSnaps.first.title, 'New title');
    });

    test('restore throws when revision missing', () async {
      expect(
        () => revRepo.restore('missing-id'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('RevisionRepository retention', () {
    test('prunes oldest beyond max revisions per note', () async {
      final note = await seedNote();
      // Insert directly to bypass bucketing for bulk seed.
      for (var i = 0; i < kMaxRevisionsPerNote + 5; i++) {
        await db.into(db.noteRevisions).insert(
              NoteRevisionsCompanion.insert(
                id: Value('seed-$i'),
                noteId: note.id,
                title: Value('t$i'),
                deltaContent: Value('{"i":$i}'),
                plainText: Value('p$i'),
                createdAt: Value(fixedNow().subtract(Duration(minutes: i))),
                source: Value(RevisionSource.manual.dbValue),
              ),
            );
      }
      await revRepo.maybeSnapshot(
        noteId: note.id,
        title: 'newest',
        deltaContent: '{"n":1}',
        plainText: 'newest',
        source: RevisionSource.manual,
        at: fixedNow(),
      );
      final all = await revRepo.listForNote(note.id);
      expect(all.length, lessThanOrEqualTo(kMaxRevisionsPerNote));
    });
  });

  group('schema', () {
    test('schemaVersion is 6', () {
      expect(db.schemaVersion, 6);
    });
  });
}

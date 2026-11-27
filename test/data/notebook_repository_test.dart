import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  late AppDatabase db;
  late NotebookRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NotebookRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('NotebookRepository', () {
    test('createNotebook inserts and returns a notebook', () async {
      final nb = await repo.createNotebook(
        name: 'Work',
        colorSeed: '#FF5722',
      );

      expect(nb.name, 'Work');
      expect(nb.colorSeed, '#FF5722');
      expect(nb.id, isNotEmpty);
      expect(nb.icon, 'notebook');
      expect(nb.sortOrder, 0);
    });

    test('createNotebook with custom icon', () async {
      final nb = await repo.createNotebook(
        name: 'Personal',
        colorSeed: '#2196F3',
        icon: 'star',
      );

      expect(nb.icon, 'star');
    });

    test('getAllNotebooks returns all notebooks ordered by sortOrder',
        () async {
      await repo.createNotebook(name: 'B', colorSeed: '#111', sortOrder: 2);
      await repo.createNotebook(name: 'A', colorSeed: '#222', sortOrder: 1);
      await repo.createNotebook(name: 'C', colorSeed: '#333', sortOrder: 0);

      final all = await repo.getAllNotebooks();
      expect(all.length, 3);
      expect(all[0].name, 'C');
      expect(all[1].name, 'A');
      expect(all[2].name, 'B');
    });

    test('getNotebookById returns the correct notebook', () async {
      final created = await repo.createNotebook(
        name: 'Find Me',
        colorSeed: '#ABC',
      );

      final found = await repo.getNotebookById(created.id);
      expect(found, isNotNull);
      expect(found!.name, 'Find Me');
    });

    test('getNotebookById returns null for nonexistent id', () async {
      final found = await repo.getNotebookById('nonexistent');
      expect(found, isNull);
    });

    test('updateNotebook modifies name and colorSeed', () async {
      final nb = await repo.createNotebook(
        name: 'Old Name',
        colorSeed: '#000',
      );

      await repo.updateNotebook(
        nb.id,
        name: 'New Name',
        colorSeed: '#FFF',
      );

      final updated = await repo.getNotebookById(nb.id);
      expect(updated!.name, 'New Name');
      expect(updated.colorSeed, '#FFF');
    });

    test('deleteNotebook removes the notebook', () async {
      final nb = await repo.createNotebook(
        name: 'Delete Me',
        colorSeed: '#123',
      );

      await repo.deleteNotebook(nb.id);

      final found = await repo.getNotebookById(nb.id);
      expect(found, isNull);
    });

    test('updateNotebook sortOrder', () async {
      final nb = await repo.createNotebook(
        name: 'Reorderable',
        colorSeed: '#456',
      );

      await repo.updateNotebook(nb.id, sortOrder: 5);

      final updated = await repo.getNotebookById(nb.id);
      expect(updated!.sortOrder, 5);
    });

    test('countNotesInNotebook returns correct count', () async {
      final nb = await repo.createNotebook(
        name: 'With Notes',
        colorSeed: '#789',
      );

      // Insert notes into the notebook
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              title: const Value('Note 1'),
              type: NoteType.text,
              deviceOriginId: 'local',
              notebookId: Value(nb.id),
            ),
          );
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              title: const Value('Note 2'),
              type: NoteType.text,
              deviceOriginId: 'local',
              notebookId: Value(nb.id),
            ),
          );
      // Note in a different notebook
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              title: const Value('Other note'),
              type: NoteType.text,
              deviceOriginId: 'local',
            ),
          );

      final count = await repo.countNotesInNotebook(nb.id);
      expect(count, 2);
    });

    test('deleteNotebookAndNotes soft-deletes notes and removes notebook',
        () async {
      final nb = await repo.createNotebook(
        name: 'Delete With Notes',
        colorSeed: '#ABC',
      );

      // Insert notes into the notebook
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              title: const Value('Note 1'),
              type: NoteType.text,
              deviceOriginId: 'local',
              notebookId: Value(nb.id),
            ),
          );
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              title: const Value('Note 2'),
              type: NoteType.text,
              deviceOriginId: 'local',
              notebookId: Value(nb.id),
            ),
          );

      await repo.deleteNotebookAndNotes(nb.id);

      // Notebook should be deleted
      final found = await repo.getNotebookById(nb.id);
      expect(found, isNull);

      // Notes should be soft-deleted (still in DB but marked deleted)
      final deletedNotes = await (db.select(db.notes)
            ..where((t) => t.deleted.equals(true)))
          .get();
      expect(deletedNotes, hasLength(2));
    });

    test('deleteNotebook only unlinks notes', () async {
      final nb = await repo.createNotebook(
        name: 'Unlink Only',
        colorSeed: '#DEF',
      );

      await db.into(db.notes).insert(
            NotesCompanion.insert(
              title: const Value('Note 1'),
              type: NoteType.text,
              deviceOriginId: 'local',
              notebookId: Value(nb.id),
            ),
          );

      await repo.deleteNotebook(nb.id);

      // Notebook should be deleted
      final found = await repo.getNotebookById(nb.id);
      expect(found, isNull);

      // Note should still be active (not soft-deleted)
      final activeNotes = await (db.select(db.notes)
            ..where((t) => t.deleted.equals(false)))
          .get();
      expect(activeNotes, hasLength(1));
      expect(activeNotes.first.notebookId, isNull);
    });

    test('softDelete marks notebook as deleted', () async {
      final nb = await repo.createNotebook(
        name: 'Soft Delete',
        colorSeed: '#111',
      );

      await repo.softDelete(nb.id);

      final all = await repo.getAllNotebooks();
      expect(all, isEmpty);

      final deleted = await repo.getDeletedNotebooks();
      expect(deleted, hasLength(1));
      expect(deleted.first.id, nb.id);
      expect(deleted.first.deleted, true);
      expect(deleted.first.deletedAt, isNotNull);
    });

    test('restore brings notebook back from soft-delete', () async {
      final nb = await repo.createNotebook(
        name: 'Restored',
        colorSeed: '#222',
      );

      await repo.softDelete(nb.id);
      expect(await repo.getAllNotebooks(), isEmpty);

      await repo.restore(nb.id);

      final all = await repo.getAllNotebooks();
      expect(all, hasLength(1));
      expect(all.first.id, nb.id);
      expect(all.first.deleted, false);
      expect(all.first.deletedAt, isNull);
    });

    test('softDeleteNotebookAndNotes soft-deletes both', () async {
      final nb = await repo.createNotebook(
        name: 'Cascade Delete',
        colorSeed: '#333',
      );

      await db.into(db.notes).insert(
            NotesCompanion.insert(
              title: const Value('Child Note'),
              type: NoteType.text,
              deviceOriginId: 'local',
              notebookId: Value(nb.id),
            ),
          );

      await repo.softDeleteNotebookAndNotes(nb.id);

      // Notebook soft-deleted
      final deletedNbs = await repo.getDeletedNotebooks();
      expect(deletedNbs, hasLength(1));

      // Note also soft-deleted
      final deletedNotes = await (db.select(db.notes)
            ..where((t) => t.deleted.equals(true)))
          .get();
      expect(deletedNotes, hasLength(1));
    });

    test('getDeletedNotebooks returns most recently deleted first', () async {
      final nb1 = await repo.createNotebook(
        name: 'First',
        colorSeed: '#AAA',
      );
      final nb2 = await repo.createNotebook(
        name: 'Second',
        colorSeed: '#BBB',
      );

      // Use direct DB updates with explicit timestamps to guarantee ordering.
      final t1 = DateTime(2025, 1, 1, 10, 0, 0);
      final t2 = DateTime(2025, 1, 1, 12, 0, 0);
      await (db.update(db.notebooks)..where((t) => t.id.equals(nb1.id))).write(
        NotebooksCompanion(
          deleted: const Value(true),
          deletedAt: Value(t1),
        ),
      );
      await (db.update(db.notebooks)..where((t) => t.id.equals(nb2.id))).write(
        NotebooksCompanion(
          deleted: const Value(true),
          deletedAt: Value(t2),
        ),
      );

      final deleted = await repo.getDeletedNotebooks();
      expect(deleted.length, 2);
      expect(deleted.first.id, nb2.id);
      expect(deleted.last.id, nb1.id);
    });

    test('getAllNotebooks excludes soft-deleted notebooks', () async {
      await repo.createNotebook(name: 'Active', colorSeed: '#111');
      final nb2 = await repo.createNotebook(
        name: 'Deleted',
        colorSeed: '#222',
      );
      await repo.softDelete(nb2.id);

      final all = await repo.getAllNotebooks();
      expect(all, hasLength(1));
      expect(all.first.name, 'Active');
    });

    test('permanentlyDelete removes notebook from DB', () async {
      final nb = await repo.createNotebook(
        name: 'To Destroy',
        colorSeed: '#333',
      );
      await repo.softDelete(nb.id);

      await repo.permanentlyDelete(nb.id);

      final deleted = await repo.getDeletedNotebooks();
      expect(deleted, isEmpty);
      final byId = await repo.getNotebookById(nb.id);
      expect(byId, isNull);
    });

    test('permanentlyDeleteAllDeleted removes all soft-deleted notebooks',
        () async {
      await repo.createNotebook(name: 'Keep', colorSeed: '#111');
      final nb1 = await repo.createNotebook(
        name: 'Gone1',
        colorSeed: '#222',
      );
      final nb2 = await repo.createNotebook(
        name: 'Gone2',
        colorSeed: '#333',
      );
      await repo.softDelete(nb1.id);
      await repo.softDelete(nb2.id);

      await repo.permanentlyDeleteAllDeleted();

      final remaining = await repo.getAllNotebooks();
      expect(remaining, hasLength(1));
      expect(remaining.first.name, 'Keep');
      final deleted = await repo.getDeletedNotebooks();
      expect(deleted, isEmpty);
    });

    test('nested notebooks: create, getRootNotebooks, getSubNotebooks',
        () async {
      final rootA =
          await repo.createNotebook(name: 'Engineering', colorSeed: '#111');
      final rootB =
          await repo.createNotebook(name: 'Personal', colorSeed: '#222');
      final subA1 = await repo.createNotebook(
        name: 'Backend',
        colorSeed: '#333',
        parentId: rootA.id,
      );
      final subA2 = await repo.createNotebook(
        name: 'Frontend',
        colorSeed: '#444',
        parentId: rootA.id,
      );

      final roots = await repo.getRootNotebooks();
      expect(roots.map((n) => n.id), containsAll([rootA.id, rootB.id]));
      expect(roots.map((n) => n.id), isNot(contains(subA1.id)));
      expect(roots.map((n) => n.id), isNot(contains(subA2.id)));

      final subsA = await repo.getSubNotebooks(rootA.id);
      expect(subsA.map((n) => n.id), containsAll([subA1.id, subA2.id]));
      expect(subsA.length, 2);

      final subsB = await repo.getSubNotebooks(rootB.id);
      expect(subsB, isEmpty);

      // Reparent subA1 to rootB
      await repo.updateNotebook(subA1.id, parentId: Value(rootB.id));
      final updatedSubsB = await repo.getSubNotebooks(rootB.id);
      expect(updatedSubsB.map((n) => n.id), contains(subA1.id));
    });

    group('Phase 13a Nested Collections Rules', () {
      test('reparenting into own descendant throws (cycle prevention)',
          () async {
        final a = await repo.createNotebook(name: 'A', colorSeed: '#111');
        final b = await repo.createNotebook(
          name: 'B',
          colorSeed: '#222',
          parentId: a.id,
        );
        final c = await repo.createNotebook(
          name: 'C',
          colorSeed: '#333',
          parentId: b.id,
        );

        // Cannot reparent A into C (C is descendant of A)
        expect(
          () => repo.reparentNotebook(a.id, c.id),
          throwsA(isA<ArgumentError>()),
        );

        // Cannot reparent A into A
        expect(
          () => repo.reparentNotebook(a.id, a.id),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('depth over 4 is rejected', () async {
        // level 0 (root) -> level 1 -> level 2 -> level 3 -> level 4
        final l0 = await repo.createNotebook(name: 'L0', colorSeed: '#000');
        final l1 = await repo.createNotebook(
            name: 'L1', colorSeed: '#111', parentId: l0.id);
        final l2 = await repo.createNotebook(
            name: 'L2', colorSeed: '#222', parentId: l1.id);
        final l3 = await repo.createNotebook(
            name: 'L3', colorSeed: '#333', parentId: l2.id);
        final l4 = await repo.createNotebook(
            name: 'L4', colorSeed: '#444', parentId: l3.id);

        expect(await repo.getNotebookDepth(l0.id), 0);
        expect(await repo.getNotebookDepth(l4.id), 4);

        // Trying to create or reparent a 5th level under l4 must throw
        expect(
          () => repo.createNotebook(
              name: 'L5', colorSeed: '#555', parentId: l4.id),
          throwsA(isA<ArgumentError>()),
        );

        final orphan =
            await repo.createNotebook(name: 'Orphan', colorSeed: '#666');
        expect(
          () => repo.reparentNotebook(orphan.id, l4.id),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('deleting parent with "Notebook only" promotes its children',
          () async {
        final root = await repo.createNotebook(name: 'Root', colorSeed: '#111');
        final mid = await repo.createNotebook(
          name: 'Middle',
          colorSeed: '#222',
          parentId: root.id,
        );
        final child = await repo.createNotebook(
          name: 'Child',
          colorSeed: '#333',
          parentId: mid.id,
        );

        // Soft-delete mid promoting its children
        await repo.softDeletePromotingChildren(mid.id);

        final updatedChild = await repo.getNotebookById(child.id);
        expect(updatedChild!.parentId, root.id);

        final midNb = await repo.getNotebookById(mid.id);
        expect(midNb!.deleted, isTrue);
      });

      test(
          'deleting with "Notes too" cascades subtree and restore brings back subtree',
          () async {
        final parent =
            await repo.createNotebook(name: 'Parent', colorSeed: '#111');
        final child = await repo.createNotebook(
          name: 'Child',
          colorSeed: '#222',
          parentId: parent.id,
        );

        // Add notes to parent and child
        final now = DateTime.now();
        await db.into(db.notes).insert(
              NotesCompanion.insert(
                id: const Value('note-parent'),
                notebookId: Value(parent.id),
                title: const Value('Parent Note'),
                type: NoteType.text,
                deviceOriginId: 'local',
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
        await db.into(db.notes).insert(
              NotesCompanion.insert(
                id: const Value('note-child'),
                notebookId: Value(child.id),
                title: const Value('Child Note'),
                type: NoteType.text,
                deviceOriginId: 'local',
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        // Cascade soft delete
        await repo.softDeleteSubtree(parent.id);

        final pNb = await repo.getNotebookById(parent.id);
        final cNb = await repo.getNotebookById(child.id);
        expect(pNb!.deleted, isTrue);
        expect(cNb!.deleted, isTrue);

        final pNote = await (db.select(db.notes)
              ..where((t) => t.id.equals('note-parent')))
            .getSingle();
        final cNote = await (db.select(db.notes)
              ..where((t) => t.id.equals('note-child')))
            .getSingle();
        expect(pNote.deleted, isTrue);
        expect(cNote.deleted, isTrue);

        // Restore subtree
        await repo.restoreSubtree(parent.id);

        final pNbRestored = await repo.getNotebookById(parent.id);
        final cNbRestored = await repo.getNotebookById(child.id);
        expect(pNbRestored!.deleted, isFalse);
        expect(cNbRestored!.deleted, isFalse);

        final pNoteRestored = await (db.select(db.notes)
              ..where((t) => t.id.equals('note-parent')))
            .getSingle();
        final cNoteRestored = await (db.select(db.notes)
              ..where((t) => t.id.equals('note-child')))
            .getSingle();
        expect(pNoteRestored.deleted, isFalse);
        expect(cNoteRestored.deleted, isFalse);
      });

      test('aggregate note count includes descendants', () async {
        final root = await repo.createNotebook(name: 'Work', colorSeed: '#111');
        final projects = await repo.createNotebook(
          name: 'Projects',
          colorSeed: '#222',
          parentId: root.id,
        );
        final nook = await repo.createNotebook(
          name: 'Nook',
          colorSeed: '#333',
          parentId: projects.id,
        );

        final now = DateTime.now();
        // 2 notes in root, 3 notes in projects, 4 notes in nook
        for (var i = 0; i < 2; i++) {
          await db.into(db.notes).insert(
                NotesCompanion.insert(
                  id: Value('note-work-$i'),
                  notebookId: Value(root.id),
                  type: NoteType.text,
                  deviceOriginId: 'local',
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
        }
        for (var i = 0; i < 3; i++) {
          await db.into(db.notes).insert(
                NotesCompanion.insert(
                  id: Value('note-proj-$i'),
                  notebookId: Value(projects.id),
                  type: NoteType.text,
                  deviceOriginId: 'local',
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
        }
        for (var i = 0; i < 4; i++) {
          await db.into(db.notes).insert(
                NotesCompanion.insert(
                  id: Value('note-nook-$i'),
                  notebookId: Value(nook.id),
                  type: NoteType.text,
                  deviceOriginId: 'local',
                  createdAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
        }

        expect(await repo.countAggregateNotes(nook.id), 4);
        expect(await repo.countAggregateNotes(projects.id), 7); // 3 + 4
        expect(await repo.countAggregateNotes(root.id), 9); // 2 + 3 + 4

        final allCounts = await repo.countAggregateNotesForAllNotebooks();
        expect(allCounts[nook.id], 4);
        expect(allCounts[projects.id], 7);
        expect(allCounts[root.id], 9);
      });
    });
  });
}

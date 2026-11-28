import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  group('Cross-note checklist task view (Phase 5)', () {
    test('returns only open tasks from live, non-archived, unlocked notes',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final noteRepo = NoteRepository(db);
      final checklistRepo = ChecklistItemRepository(db);

      final active = await noteRepo.createNote(
        id: 'task-note-active',
        title: 'Release Tasks',
        type: NoteType.checklist,
        deviceOriginId: 'dev-1',
      );
      await checklistRepo.addItem(
        noteId: active.id,
        text: 'Run full test suite',
        checked: false,
      );
      await checklistRepo.addItem(
        noteId: active.id,
        text: 'Already done',
        checked: true,
      );

      final locked = await noteRepo.createNote(
        id: 'task-note-locked',
        title: 'Secret Tasks',
        type: NoteType.checklist,
        deviceOriginId: 'dev-1',
      );
      await noteRepo.updateNote(locked.id, locked: true);
      await checklistRepo.addItem(
        noteId: locked.id,
        text: 'Secret open item',
        checked: false,
      );

      final open = await checklistRepo.getOpenTasksAcrossNotes();
      expect(open, hasLength(1));
      expect(open.single.item.itemText, 'Run full test suite');
      expect(open.single.note.id, active.id);
    });
  });
}

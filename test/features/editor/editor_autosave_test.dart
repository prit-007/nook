import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/editor_autosave.dart';

void main() {
  late AppDatabase db;
  late NoteRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = NoteRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('EditorAutosaveController', () {
    test('snapshotContent captures title, deltaJson, and plainText', () async {
      final note = await repo.createNote(
        title: '',
        type: NoteType.text,
        deviceOriginId: 'local',
      );

      final document = Document(
        root: Node(
          type: 'page',
          children: [
            paragraphNode(text: 'My Document Title\nSecond line of content'),
          ],
        ),
      );
      final editorState = EditorState(document: document);

      final snapshot = EditorAutosaveController.snapshotContent(
        editorState: editorState,
        currentTitle: '',
        noteId: note.id,
        db: db,
      );

      expect(snapshot.noteId, equals(note.id));
      expect(snapshot.title, equals('My Document Title'));
      expect(snapshot.plainText, contains('Second line of content'));
      expect(snapshot.deltaJson, isNotEmpty);
    });

    test('persistSnapshot writes content and title to database', () async {
      final note = await repo.createNote(
        title: '',
        type: NoteType.text,
        deviceOriginId: 'local',
      );

      final snapshot = PersistSnapshot(
        noteId: note.id,
        title: 'Updated Header',
        deltaJson: '{"test": 123}',
        plainText: 'Plain text content',
        db: db,
      );

      await EditorAutosaveController.persistSnapshot(snapshot);

      final updated = await repo.getNoteById(note.id);
      expect(updated, isNotNull);
      expect(updated!.title, equals('Updated Header'));
      expect(updated.deltaContent, equals('{"test": 123}'));
      expect(updated.plainText, equals('Plain text content'));
    });

    test('scheduleAutosave debounces multiple rapid calls', () async {
      final controller = EditorAutosaveController();
      int saveCount = 0;

      controller.scheduleAutosave(
        onSave: () async {
          saveCount++;
        },
        delay: const Duration(milliseconds: 50),
      );
      controller.scheduleAutosave(
        onSave: () async {
          saveCount++;
        },
        delay: const Duration(milliseconds: 50),
      );
      controller.scheduleAutosave(
        onSave: () async {
          saveCount++;
        },
        delay: const Duration(milliseconds: 50),
      );

      expect(saveCount, equals(0));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(saveCount, equals(1));

      controller.dispose(
        editorState: null,
        note: null,
        db: null,
        currentTitle: '',
        dirty: false,
      );
    });
  });
}

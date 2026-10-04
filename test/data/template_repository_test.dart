import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/template_repository.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  late AppDatabase db;
  late NoteRepository noteRepo;
  late TemplateRepository templateRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    noteRepo = NoteRepository(db);
    templateRepo = TemplateRepository(db);
  });

  tearDown(() async => db.close());

  group('TemplateRepository', () {
    test('seedBuiltinsIfEmpty is idempotent', () async {
      final first = await templateRepo.seedBuiltinsIfEmpty();
      expect(first, TemplateRepository.builtinSeeds.length);
      final second = await templateRepo.seedBuiltinsIfEmpty();
      expect(second, 0);
      final all = await templateRepo.all();
      expect(all.length, TemplateRepository.builtinSeeds.length);
      expect(all.map((t) => t.name), contains('Meeting notes'));
      expect(all.map((t) => t.name), contains('Reading list'));
    });

    test('createNoteFromTemplate copies content into a new note', () async {
      await templateRepo.seedBuiltinsIfEmpty();
      final templates = await templateRepo.all();
      final meeting = templates.firstWhere((t) => t.name == 'Meeting notes');

      final note = await templateRepo.createNoteFromTemplate(meeting.id);
      expect(note.id, isNot(meeting.id));
      expect(note.title, 'Meeting notes');
      expect(note.plainText, meeting.plainText);

      // Template still exists — create is not a consume.
      expect(await templateRepo.byId(meeting.id), isNotNull);
    });

    test('checklist template produces NoteType.checklist', () async {
      await templateRepo.seedBuiltinsIfEmpty();
      final templates = await templateRepo.all();
      final checklist =
          templates.firstWhere((t) => t.name == 'Blank checklist');
      final note = await templateRepo.createNoteFromTemplate(checklist.id);
      expect(note.type, NoteType.checklist);
    });

    test('saveNoteAsTemplate snapshots current note content', () async {
      final note = await noteRepo.createNote(
        title: 'Draft',
        type: NoteType.text,
        deviceOriginId: 'd1',
        plainText: 'snapshot me',
        deltaContent: '{"v":1}',
      );
      final template = await templateRepo.saveNoteAsTemplate(
        note,
        name: 'From draft',
      );
      expect(template.name, 'From draft');
      expect(template.plainText, 'snapshot me');
      expect(template.deltaContent, '{"v":1}');
    });

    test('delete template does not delete notes created from it', () async {
      await templateRepo.seedBuiltinsIfEmpty();
      final templates = await templateRepo.all();
      final t = templates.first;
      final note = await templateRepo.createNoteFromTemplate(t.id);
      await templateRepo.delete(t.id);

      expect(await templateRepo.byId(t.id), isNull);
      final live = await noteRepo.getNoteById(note.id);
      expect(live, isNotNull);
      expect(live!.title, t.name);
    });

    test('createNoteFromTemplate throws for missing template', () async {
      expect(
        () => templateRepo.createNoteFromTemplate('missing'),
        throwsA(isA<StateError>()),
      );
    });

    test('schemaVersion is 7', () {
      expect(db.schemaVersion, 7);
    });
  });
}

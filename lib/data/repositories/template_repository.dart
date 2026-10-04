import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/talker_provider.dart';
import '../database.dart';
import '../tables/notes.dart';
import 'note_repository.dart';

/// CRUD for local note templates. Creating a note from a template always
/// inserts a **new** Notes row — deleting a template never deletes notes.
class TemplateRepository {
  TemplateRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  static const List<({String name, String markdownSeed})> builtinSeeds = [
    (
      name: 'Meeting notes',
      markdownSeed:
          '# Meeting\n\n**Date:**\n**Attendees:**\n\n## Agenda\n- \n\n## Notes\n- \n\n## Actions\n- [ ] \n',
    ),
    (
      name: 'Daily journal',
      markdownSeed:
          '# Daily journal\n\n## Morning\n- \n\n## Focus\n- \n\n## Evening reflection\n- \n',
    ),
    (
      name: 'Reading list',
      markdownSeed: '# Reading list\n\n- [ ] \n- [ ] \n- [ ] \n',
    ),
    (
      name: 'Blank checklist',
      markdownSeed: '# Checklist\n\n- [ ] \n- [ ] \n',
    ),
  ];

  /// Idempotent seed of built-in templates (no-op if any templates exist).
  Future<int> seedBuiltinsIfEmpty() async {
    final existing = await (_db.select(_db.templates)..limit(1)).get();
    if (existing.isNotEmpty) return 0;
    var created = 0;
    for (final seed in builtinSeeds) {
      await _db.into(_db.templates).insert(
            TemplatesCompanion.insert(
              id: Value(_uuid.v4()),
              name: seed.name,
              plainText: Value(seed.markdownSeed),
            ),
          );
      created++;
    }
    nookLog(
      NookLogKey.database,
      'Seeded $created builtin templates',
      LogLevel.info,
    );
    return created;
  }

  Future<List<Template>> all() {
    return (_db.select(_db.templates)
          ..orderBy([
            (t) => OrderingTerm.desc(t.pinned),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .get();
  }

  Future<Template?> byId(String id) {
    return (_db.select(_db.templates)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Template> create({
    required String name,
    String? deltaContent,
    String? plainText,
    String? colorSeed,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.templates).insert(
          TemplatesCompanion.insert(
            id: Value(id),
            name: name,
            deltaContent: Value(deltaContent),
            plainText: Value(plainText),
            colorSeed: Value(colorSeed),
          ),
        );
    return (_db.select(_db.templates)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  /// Saves the current note content as a new template.
  Future<Template> saveNoteAsTemplate(Note note, {required String name}) {
    return create(
      name: name,
      deltaContent: note.deltaContent,
      plainText: note.plainText,
      colorSeed: note.colorSeed,
    );
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.templates)..where((t) => t.id.equals(id))).go();
  }

  /// Creates a **new** note from [templateId] (copy, not a FK link).
  Future<Note> createNoteFromTemplate(String templateId) async {
    final template = await byId(templateId);
    if (template == null) {
      throw StateError('Template $templateId not found');
    }
    final isChecklist = RegExp(r'^\s*- \[[ xX]\]', multiLine: true)
        .hasMatch(template.plainText ?? '');
    final note = await NoteRepository(_db).createNote(
      title: template.name,
      type: isChecklist ? NoteType.checklist : NoteType.text,
      deviceOriginId: 'local',
      deltaContent: template.deltaContent,
      plainText: template.plainText,
      colorSeed: template.colorSeed,
    );
    nookLog(
      NookLogKey.database,
      'Note ${note.id} created from template ${template.id}',
      LogLevel.info,
    );
    return note;
  }
}

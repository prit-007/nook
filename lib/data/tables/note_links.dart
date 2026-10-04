import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'notes.dart';

/// Bidirectional cache of `nook://note/<id>` links extracted from note
/// documents. Source of truth remains the AppFlowy delta JSON — this table is
/// rebuilt whenever `deltaContent` is written.
class NoteLinks extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  @ReferenceName('noteLinkSources')
  TextColumn get sourceNoteId =>
      text().references(Notes, #id, onDelete: KeyAction.cascade)();

  @ReferenceName('noteLinkTargets')
  TextColumn get targetNoteId =>
      text().references(Notes, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

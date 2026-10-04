import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'notes.dart';

/// Snapshot of a note's content at a point in time (version history).
///
/// Revisions are local-only in v1 — they are not synced and not included in
/// `.nook` export. Restore always snapshots the current state first.
class NoteRevisions extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get noteId =>
      text().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get deltaContent => text().nullable()();
  TextColumn get plainText => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  /// autosave | manual | restore
  TextColumn get source => text().withDefault(const Constant('autosave'))();

  @override
  Set<Column> get primaryKey => {id};
}

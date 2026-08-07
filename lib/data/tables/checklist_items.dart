import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'notes.dart';

class ChecklistItems extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get noteId => text().references(Notes, #id)();
  TextColumn get itemText => text()();
  BoolColumn get checked => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

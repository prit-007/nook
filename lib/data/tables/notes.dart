import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'notebooks.dart';

enum NoteType { text, checklist, doodle, mixed }

class Notes extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get notebookId => text().nullable().references(Notebooks, #id)();
  TextColumn get type => textEnum<NoteType>()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get deltaContent => text().nullable()();
  TextColumn get plainText => text().nullable()();
  TextColumn get colorSeed => text().nullable()();
  TextColumn get coverImagePath => text().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get locked => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();
  TextColumn get deviceOriginId => text()();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

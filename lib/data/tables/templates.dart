import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Reusable note template (local-only).
class Templates extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text()();
  TextColumn get deltaContent => text().nullable()();
  TextColumn get plainText => text().nullable()();
  TextColumn get colorSeed => text().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

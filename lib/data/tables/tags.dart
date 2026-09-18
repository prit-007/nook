import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class Tags extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get colorSeed => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

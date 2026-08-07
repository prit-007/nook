import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class Notebooks extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get colorSeed => text()();
  TextColumn get icon => text().withDefault(const Constant('notebook'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'notes.dart';

/// How often a reminder repeats.
enum ReminderRepeat {
  none('none'),
  daily('daily'),
  weekly('weekly'),
  monthly('monthly');

  const ReminderRepeat(this.dbValue);
  final String dbValue;

  static ReminderRepeat fromDb(String value) =>
      ReminderRepeat.values.firstWhere(
        (r) => r.dbValue == value,
        orElse: () => ReminderRepeat.none,
      );
}

/// Local reminder attached to a note.
class Reminders extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get noteId =>
      text().references(Notes, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
  DateTimeColumn get fireAt => dateTime()();

  /// none | daily | weekly | monthly
  TextColumn get repeat => text().withDefault(const Constant('none'))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

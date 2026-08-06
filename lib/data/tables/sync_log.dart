import 'package:drift/drift.dart';

enum SyncAction { sent, received, conflict }

class SyncLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text()();
  TextColumn get deviceName => text()();
  TextColumn get noteId => text()();
  TextColumn get action => textEnum<SyncAction>()();
  DateTimeColumn get timestamp => dateTime().clientDefault(DateTime.now)();
}

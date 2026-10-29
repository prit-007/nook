import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

/// Persisted paired devices that can automatically connect and sync without
/// repeating manual 6-digit confirmation codes.
class TrustedDevices extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get peerId => text().unique()();
  TextColumn get deviceName => text()();
  TextColumn get publicKey => text().nullable()();
  DateTimeColumn get trustedAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  BoolColumn get autoSyncEnabled =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

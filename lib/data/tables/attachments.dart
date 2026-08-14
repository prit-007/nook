import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'notes.dart';

enum AttachmentType { image, doodleLayer }

class Attachments extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get noteId => text().references(Notes, #id)();
  TextColumn get type => textEnum<AttachmentType>()();
  TextColumn get filePath => text()();
  TextColumn get thumbnailPath => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

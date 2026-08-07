import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/providers/notes_list_provider.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> insertNote({
    String title = 'Test Note',
    NoteType type = NoteType.text,
    bool deleted = false,
  }) async {
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            title: Value(title),
            type: type,
            deviceOriginId: 'device-1',
            deleted: Value(deleted),
          ),
        );
  }

  group('notesListProvider', () {
    test('emits empty list when no notes exist', () async {
      final sub = container.listen(notesListProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);

      final value = container.read(notesListProvider);
      expect(value.value, isEmpty);

      sub.close();
    });

    test('emits all non-deleted notes', () async {
      await insertNote(title: 'Note 1');
      await insertNote(title: 'Note 2');
      await insertNote(title: 'Deleted', deleted: true);

      final sub = container.listen(notesListProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);

      final value = container.read(notesListProvider);
      expect(value.value!.length, 2);

      sub.close();
    });

    test('orders by pinned first then updatedAt desc', () async {
      await insertNote(title: 'Regular');
      await insertNote(title: 'Pinned');

      await (db.update(db.notes)..where((t) => t.title.equals('Pinned')))
          .write(const NotesCompanion(pinned: Value(true)));

      final sub = container.listen(notesListProvider, (_, __) {});
      await Future<void>.delayed(Duration.zero);

      final value = container.read(notesListProvider);
      expect(value.value!.first.title, 'Pinned');
      expect(value.value!.last.title, 'Regular');

      sub.close();
    });
  });
}

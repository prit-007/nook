import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/tags/tag_detail_screen.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> createTag(String name) async {
    final repo = TagRepository(db);
    final tag = await repo.createTag(name: name, colorSeed: '#2196F3');
    return tag.id;
  }

  Future<String> createNote(String title) async {
    final repo = NoteRepository(db);
    final note = await repo.createNote(
      title: title,
      type: NoteType.text,
      deviceOriginId: 'local',
    );
    return note.id;
  }

  Future<void> tagNote(String noteId, String tagId) async {
    final repo = TagRepository(db);
    await repo.assignTagToNote(noteId, tagId);
  }

  Widget buildScreen(String tagId) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: TagDetailScreen(tagId: tagId),
      ),
    );
  }

  group('TagDetailScreen', () {
    testWidgets('empty state shows no notes message', (tester) async {
      final tagId = await createTag('empty-tag');

      await tester.pumpWidget(buildScreen(tagId));
      await tester.pumpAndSettle();

      expect(find.text('No notes found'), findsOneWidget);
    });

    testWidgets('tagged notes are displayed', (tester) async {
      final tagId = await createTag('work');
      final noteId = await createNote('Work Note');
      await tagNote(noteId, tagId);

      await tester.pumpWidget(buildScreen(tagId));
      await tester.pumpAndSettle();

      expect(find.text('Work Note'), findsWidgets);
    });

    testWidgets('FAB for adding notes is visible', (tester) async {
      final tagId = await createTag('personal');

      await tester.pumpWidget(buildScreen(tagId));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is FloatingActionButton ||
              (w is IconButton &&
                  w.tooltip != null &&
                  w.tooltip!.toLowerCase().contains('add')),
        ),
        findsWidgets,
      );
    });
  });
}

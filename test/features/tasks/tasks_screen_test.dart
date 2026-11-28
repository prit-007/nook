import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/tasks/tasks_screen.dart';

void main() {
  group('TasksScreen navigation & M3 fluidity', () {
    testWidgets('displays open tasks across notes and toggles completion',
        (tester) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final noteRepo = NoteRepository(db);
      final checklistRepo = ChecklistItemRepository(db);

      final note = await noteRepo.createNote(
        id: 'tasks-ui-note-1',
        title: 'Launch Checklist',
        type: NoteType.checklist,
        deviceOriginId: 'dev-1',
      );
      await checklistRepo.addItem(
        noteId: note.id,
        text: 'Verify release notes',
        checked: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: TasksScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Open Tasks'), findsOneWidget);
      expect(find.text('Verify release notes'), findsOneWidget);
      expect(find.text('Launch Checklist'), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(find.text('All caught up'), findsOneWidget);
    });
  });
}

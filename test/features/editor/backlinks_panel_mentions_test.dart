import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/widgets/backlinks_panel.dart';

void main() {
  group('BacklinksPanel unlinked mentions', () {
    testWidgets('surfaces unlinked mentions for the active note',
        (tester) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final noteRepo = NoteRepository(db);
      final target = await noteRepo.createNote(
        id: 'bp-target',
        title: 'Design System',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
      );
      await noteRepo.createNote(
        id: 'bp-mention',
        title: 'Weekly Sync',
        plainText: 'Reviewed Design System motion tokens.',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BacklinksPanel(note: target),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Unlinked mentions (1)'), findsOneWidget);
      expect(find.text('Weekly Sync'), findsOneWidget);
    });
  });
}

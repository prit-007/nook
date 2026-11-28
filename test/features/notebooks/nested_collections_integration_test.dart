import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/notebooks/notebooks_screen.dart';
import 'package:nook/features/notebooks/widgets/mobile_collection_drill_down.dart';

void main() {
  late AppDatabase db;
  late NotebookRepository notebookRepo;
  late NoteRepository noteRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    notebookRepo = NotebookRepository(db);
    noteRepo = NoteRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
      'Integration: 3-level hierarchy, move note into it, delete middle level, confirm children promote',
      () async {
    // 1. Create a 3-level hierarchy
    final engineering = await notebookRepo.createNotebook(
      name: 'Engineering',
      colorSeed: '#111',
    );
    final apps = await notebookRepo.createNotebook(
      name: 'Apps',
      colorSeed: '#222',
      parentId: engineering.id,
    );
    final nookCollection = await notebookRepo.createNotebook(
      name: 'Nook',
      colorSeed: '#333',
      parentId: apps.id,
    );

    expect(await notebookRepo.getNotebookDepth(engineering.id), 0);
    expect(await notebookRepo.getNotebookDepth(apps.id), 1);
    expect(await notebookRepo.getNotebookDepth(nookCollection.id), 2);

    // 2. Move / create a note inside the leaf collection (Nook)
    final note = await noteRepo.createNote(
      title: 'Sync Architecture',
      type: NoteType.text,
      notebookId: nookCollection.id,
      deviceOriginId: 'local',
    );

    expect(note.notebookId, nookCollection.id);
    expect(await notebookRepo.countAggregateNotes(nookCollection.id), 1);
    expect(await notebookRepo.countAggregateNotes(apps.id), 1);
    expect(await notebookRepo.countAggregateNotes(engineering.id), 1);

    // 3. Delete the middle level (Apps) with "Notebook only" (promote children)
    await notebookRepo.softDeletePromotingChildren(apps.id);

    // 4. Confirm children promote: Nook's parent is now Engineering
    final updatedNook = await notebookRepo.getNotebookById(nookCollection.id);
    expect(updatedNook, isNotNull);
    expect(updatedNook!.parentId, engineering.id);
    expect(await notebookRepo.getNotebookDepth(nookCollection.id), 1);

    // 5. Confirm note is intact and aggregate counts are preserved
    final noteAfter = await noteRepo.getNoteById(note.id);
    expect(noteAfter, isNotNull);
    expect(noteAfter!.notebookId, nookCollection.id);
    expect(noteAfter.deleted, isFalse);

    expect(await notebookRepo.countAggregateNotes(nookCollection.id), 1);
    expect(await notebookRepo.countAggregateNotes(engineering.id), 1);
  });

  testWidgets(
      'NotebooksScreen wires MobileCollectionDrillDown on mobile for nested collections',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final work = await notebookRepo.createNotebook(
      name: 'Work',
      colorSeed: '#111111',
    );
    await notebookRepo.createNotebook(
      name: 'Nook',
      colorSeed: '#222222',
      parentId: work.id,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: NotebooksScreen(viewMode: NotebookViewMode.drillDown),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MobileCollectionDrillDown), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(find.text('Collections'), findsOneWidget);
    expect(find.text('Nook'), findsWidgets);
  });
}

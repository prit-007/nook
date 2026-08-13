import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/data/tables/attachments.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/notebooks/widgets/notebook_card.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late NotebookRepository repo;

  setUp(() {
    db = createTestDb();
    repo = NotebookRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Notebook> insertNotebook(String name, {String colorSeed = '#FF5722'}) {
    return repo.createNotebook(name: name, colorSeed: colorSeed);
  }

  Future<void> insertNoteWithImage(
    String notebookId, {
    required String filePath,
    required DateTime updatedAt,
  }) async {
    final noteId = 'note-$filePath';
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: Value(noteId),
            notebookId: Value(notebookId),
            title: Value('Note $filePath'),
            type: NoteType.text,
            deviceOriginId: 'device-1',
            updatedAt: Value(updatedAt),
          ),
        );
    await db.into(db.attachments).insert(
          AttachmentsCompanion.insert(
            id: Value('att-$filePath'),
            noteId: noteId,
            type: AttachmentType.image,
            filePath: filePath,
          ),
        );
  }

  Widget buildCard(Notebook notebook, {int noteCount = 3}) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 290,
            child: NotebookCard(notebook: notebook, noteCount: noteCount),
          ),
        ),
      ),
    );
  }

  group('NotebookCard', () {
    testWidgets('renders name and note count', (tester) async {
      final nb = await insertNotebook('Ideas');
      await tester.pumpWidget(buildCard(nb, noteCount: 12));
      await tester.pumpAndSettle();

      expect(find.text('Ideas'), findsOneWidget);
      expect(find.text('12 entries'), findsOneWidget);
    });

    testWidgets('uses singular note label for one note', (tester) async {
      final nb = await insertNotebook('Journal');
      await tester.pumpWidget(buildCard(nb, noteCount: 1));
      await tester.pumpAndSettle();

      expect(find.text('1 entry'), findsOneWidget);
    });

    testWidgets('renders macro typography kicker', (tester) async {
      final nb = await insertNotebook('Ideas');
      await tester.pumpWidget(buildCard(nb));
      await tester.pumpAndSettle();

      final nameText = tester.widget<Text>(find.text('Ideas'));
      expect(nameText.style?.fontSize, 32);
      expect(nameText.style?.fontWeight, FontWeight.w800);
      expect(find.text('NOTEBOOK'), findsOneWidget);
    });

    testWidgets('falls back to seed color without images', (tester) async {
      final nb = await insertNotebook('Ideas');
      await tester.pumpWidget(buildCard(nb));
      await tester.pumpAndSettle();

      expect(find.text('Ideas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ignores unreadable image file gracefully', (tester) async {
      final nb = await insertNotebook('Ideas');
      await insertNoteWithImage(nb.id,
          filePath: '/no/such/image.png', updatedAt: DateTime.now());
      await tester.pumpWidget(buildCard(nb));
      await tester.pumpAndSettle();

      expect(find.text('Ideas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long name in narrow portrait grid never overflows',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final nb = await insertNotebook(
        'An extremely long notebook name that wraps onto many lines',
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 0.65,
              ),
              itemCount: 1,
              itemBuilder: (_, __) => NotebookCard(notebook: nb, noteCount: 0),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('An extremely long'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('NotebookRepository.getLatestImageForNotebook', () {
    test('returns null when notebook has no image attachments', () async {
      final nb = await insertNotebook('Empty');
      final result = await repo.getLatestImageForNotebook(nb.id);
      expect(result, isNull);
    });

    test('returns most recently updated image', () async {
      final nb = await insertNotebook('Shelf');
      await insertNoteWithImage(
        nb.id,
        filePath: 'old.png',
        updatedAt: DateTime(2026, 1, 1),
      );
      await insertNoteWithImage(
        nb.id,
        filePath: 'new.png',
        updatedAt: DateTime(2026, 6, 1),
      );

      final result = await repo.getLatestImageForNotebook(nb.id);
      expect(result, isNotNull);
      expect(result!.filePath, 'new.png');
    });

    test('ignores image attachments of deleted notes', () async {
      final nb = await insertNotebook('Shelf');
      final noteId = 'deleted-note';
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: Value(noteId),
              notebookId: Value(nb.id),
              title: const Value('Gone'),
              type: NoteType.text,
              deviceOriginId: 'device-1',
              deleted: const Value(true),
            ),
          );
      await db.into(db.attachments).insert(
            AttachmentsCompanion.insert(
              id: const Value('att-deleted'),
              noteId: noteId,
              type: AttachmentType.image,
              filePath: 'gone.png',
            ),
          );

      final result = await repo.getLatestImageForNotebook(nb.id);
      expect(result, isNull);
    });

    test('does not leak images from other notebooks', () async {
      final a = await insertNotebook('A');
      final b = await insertNotebook('B');
      await insertNoteWithImage(a.id,
          filePath: 'a.png', updatedAt: DateTime(2026, 1, 1));

      final result = await repo.getLatestImageForNotebook(b.id);
      expect(result, isNull);
    });
  });
}

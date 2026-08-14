import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/widgets/note_banner_card.dart';
import 'package:nook/features/home/widgets/note_card.dart';
import 'package:nook/features/home/widgets/note_doodle_card.dart';
import 'package:nook/features/home/widgets/note_minimal_card.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<Note> createNote({
    required String id,
    String title = 'Test Note',
    NoteType type = NoteType.text,
    String? notebookId,
  }) async {
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: Value(id),
            title: Value(title),
            type: type,
            deviceOriginId: 'device-1',
            notebookId: Value(notebookId),
          ),
        );
    return (db.select(db.notes)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> createNotebook(String id, String name) async {
    await db.into(db.notebooks).insert(
          NotebooksCompanion.insert(
            id: Value(id),
            name: name,
            colorSeed: '#6750A4',
          ),
        );
  }

  Future<void> createTagsForNote(String noteId, int count) async {
    for (var i = 0; i < count; i++) {
      await db.into(db.tags).insert(
            TagsCompanion.insert(
              id: Value('tag-$noteId-$i'),
              name: 'tag$i',
              colorSeed: '#FF${i.toRadixString(16).padLeft(4, '0')}',
            ),
          );
      await db.into(db.noteTags).insert(
            NoteTagsCompanion.insert(
              noteId: noteId,
              tagId: 'tag-$noteId-$i',
            ),
          );
    }
  }

  /// Wraps [child] in the minimum tree needed for a note card to render
  /// inside a bounded [SizedBox], with the real database wired up.
  Widget wrapForOverflow(Widget child, {double width = 280, double height = 400}) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: child,
          ),
        ),
      ),
    );
  }

  group('NoteCard metadata overflow', () {
    testWidgets('notebook + 5 tags in narrow card', (tester) async {
      tester.view.physicalSize = const Size(320, 580);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await createNotebook('nb-1', 'Design Systems');
      final note = await createNote(
        id: 'n1',
        title: 'Color Palette',
        notebookId: 'nb-1',
      );
      await createTagsForNote('n1', 5);

      await tester.pumpWidget(wrapForOverflow(NoteCard(note: note)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('notebook + 10 tags in narrow card', (tester) async {
      tester.view.physicalSize = const Size(280, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await createNotebook('nb-2', 'Very Long Notebook Name That Should Ellipsize');
      final note = await createNote(
        id: 'n2',
        title: 'Dense Note',
        notebookId: 'nb-2',
      );
      await createTagsForNote('n2', 10);

      await tester.pumpWidget(wrapForOverflow(NoteCard(note: note)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('5 tags, no notebook', (tester) async {
      tester.view.physicalSize = const Size(300, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final note = await createNote(id: 'n3', title: 'Tags Only');
      await createTagsForNote('n3', 5);

      await tester.pumpWidget(wrapForOverflow(NoteCard(note: note)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('NoteMinimalCard metadata overflow', () {
    testWidgets('notebook + 5 tags', (tester) async {
      tester.view.physicalSize = const Size(320, 580);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await createNotebook('nb-m1', 'Research');
      final note = await createNote(
        id: 'nm1',
        title: 'Minimal',
        notebookId: 'nb-m1',
      );
      await createTagsForNote('nm1', 5);

      await tester.pumpWidget(wrapForOverflow(NoteMinimalCard(note: note)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('10 tags, no notebook', (tester) async {
      tester.view.physicalSize = const Size(280, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final note = await createNote(id: 'nm2', title: 'Many Tags');
      await createTagsForNote('nm2', 10);

      await tester.pumpWidget(wrapForOverflow(NoteMinimalCard(note: note)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('NoteBannerCard metadata overflow', () {
    testWidgets('notebook + 5 tags in 320px card', (tester) async {
      tester.view.physicalSize = const Size(320, 580);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await createNotebook('nb-b1', 'Projects');
      final note = await createNote(
        id: 'nb1',
        title: 'Banner',
        notebookId: 'nb-b1',
      );
      await createTagsForNote('nb1', 5);

      await tester.pumpWidget(wrapForOverflow(
        NoteBannerCard(note: note),
        width: 320,
        height: 240,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('notebook + 10 tags', (tester) async {
      tester.view.physicalSize = const Size(280, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await createNotebook('nb-b2', 'A Very Long Notebook Name');
      final note = await createNote(
        id: 'nb2',
        title: 'Banner Dense',
        notebookId: 'nb-b2',
      );
      await createTagsForNote('nb2', 10);

      await tester.pumpWidget(wrapForOverflow(
        NoteBannerCard(note: note),
        width: 280,
        height: 240,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('NoteDoodleCard metadata overflow', () {
    testWidgets('notebook + 5 tags', (tester) async {
      tester.view.physicalSize = const Size(320, 580);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await createNotebook('nb-d1', 'Art');
      final note = await createNote(
        id: 'nd1',
        title: 'Doodle',
        type: NoteType.doodle,
        notebookId: 'nb-d1',
      );
      await createTagsForNote('nd1', 5);

      await tester.pumpWidget(wrapForOverflow(
        NoteDoodleCard(note: note),
        width: 320,
        height: 160,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('10 tags, no notebook', (tester) async {
      tester.view.physicalSize = const Size(280, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final note = await createNote(
        id: 'nd2',
        title: 'Doodle Tags',
        type: NoteType.doodle,
      );
      await createTagsForNote('nd2', 10);

      await tester.pumpWidget(wrapForOverflow(
        NoteDoodleCard(note: note),
        width: 280,
        height: 160,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

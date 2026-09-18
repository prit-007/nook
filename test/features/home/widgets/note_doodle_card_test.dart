import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/providers/note_card_metadata_provider.dart';
import 'package:nook/features/home/widgets/note_doodle_card.dart';

void main() {
  late AppDatabase db;
  late Directory tmpDir;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tmpDir = Directory.systemTemp.createTempSync('doodle_card_test');
  });

  tearDown(() async {
    tmpDir.deleteSync(recursive: true);
    await db.close();
  });

  Future<Note> insertDoodleNote({
    String id = 'doodle-1',
    String title = 'My Doodle',
    bool pinned = false,
  }) async {
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: Value(id),
            title: Value(title),
            type: NoteType.doodle,
            pinned: Value(pinned),
            deviceOriginId: 'device-1',
          ),
        );
    return (db.select(db.notes)..where((t) => t.id.equals(id))).getSingle();
  }

  Widget buildCard(Note note, {NoteCardMetadata? metadata}) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 200,
            child: NoteDoodleCard(note: note, preloadedMetadata: metadata),
          ),
        ),
      ),
    );
  }

  group('NoteDoodleCard', () {
    testWidgets('shows fallback icon when no thumbnail path', (tester) async {
      final note = await insertDoodleNote();

      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      expect(find.byType(NoteDoodleCard), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedPenTool01),
        findsOneWidget,
      );
    });

    testWidgets('shows thumbnail image when path is valid', (tester) async {
      final note = await insertDoodleNote(id: 'doodle-thumb');
      final thumbFile = File('${tmpDir.path}/thumb.png');
      thumbFile.writeAsBytesSync([0]);

      final metadata = NoteCardMetadata(thumbnailPath: thumbFile.path);

      await tester.pumpWidget(buildCard(note, metadata: metadata));
      await tester.pumpAndSettle();

      expect(find.byType(NoteDoodleCard), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shows fallback icon when thumbnail path is invalid',
        (tester) async {
      final note = await insertDoodleNote(id: 'doodle-bad');
      final metadata = const NoteCardMetadata(
        thumbnailPath: '/nonexistent/path/thumb.png',
      );

      await tester.pumpWidget(buildCard(note, metadata: metadata));
      await tester.pumpAndSettle();

      expect(find.byType(NoteDoodleCard), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedPenTool01),
        findsOneWidget,
      );
    });

    testWidgets('displays note title', (tester) async {
      final note = await insertDoodleNote(title: 'Sketch Book');

      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      expect(find.text('Sketch Book'), findsOneWidget);
    });

    testWidgets('shows Doodle label for doodle type', (tester) async {
      final note = await insertDoodleNote();

      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      expect(find.text('Doodle'), findsOneWidget);
    });

    testWidgets('shows Mixed note label for mixed type', (tester) async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('mixed-1'),
              title: const Value('Mixed Thing'),
              type: NoteType.mixed,
              deviceOriginId: 'device-1',
            ),
          );
      final note = await (db.select(db.notes)
            ..where((t) => t.id.equals('mixed-1')))
          .getSingle();

      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      expect(find.text('Mixed note'), findsOneWidget);
    });

    testWidgets('shows pin icon when pinned', (tester) async {
      final note = await insertDoodleNote(pinned: true);

      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedPin),
        findsOneWidget,
      );
    });

    testWidgets('shows metadata row with notebook and tags', (tester) async {
      tester.view.physicalSize = const Size(400, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await db.into(db.notebooks).insert(
            NotebooksCompanion.insert(
              id: const Value('nb-doodle'),
              name: 'Art Book',
              colorSeed: '#FF5722',
            ),
          );
      await db.into(db.tags).insert(
            TagsCompanion.insert(
              id: const Value('tag-doodle'),
              name: 'sketch',
              colorSeed: '#4CAF50',
            ),
          );

      final note = await insertDoodleNote(id: 'doodle-meta');
      await (db.update(db.notes)..where((t) => t.id.equals('doodle-meta')))
          .write(const NotesCompanion(notebookId: Value('nb-doodle')));
      await db.into(db.noteTags).insert(
            NoteTagsCompanion.insert(
                noteId: 'doodle-meta', tagId: 'tag-doodle'),
          );

      final metadata = NoteCardMetadata(
        notebookName: 'Art Book',
        tags: [
          await (db.select(db.tags)..where((t) => t.id.equals('tag-doodle')))
              .getSingle(),
        ],
      );

      await tester.pumpWidget(buildCard(note, metadata: metadata));
      await tester.pumpAndSettle();

      expect(find.text('Art Book'), findsOneWidget);
      expect(find.text('sketch'), findsOneWidget);
    });

    testWidgets('shows Untitled doodle when title is empty', (tester) async {
      await db.into(db.notes).insert(
            NotesCompanion.insert(
              id: const Value('doodle-empty'),
              title: const Value(''),
              type: NoteType.doodle,
              deviceOriginId: 'device-1',
            ),
          );
      final note = await (db.select(db.notes)
            ..where((t) => t.id.equals('doodle-empty')))
          .getSingle();

      await tester.pumpWidget(buildCard(note));
      await tester.pumpAndSettle();

      expect(find.text('Untitled doodle'), findsOneWidget);
    });
  });
}

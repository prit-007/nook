import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/attachments.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/trash/trash_screen.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertDeletedNote({
    required String id,
    required String title,
  }) async {
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: Value(id),
            title: Value(title),
            type: NoteType.text,
            deviceOriginId: 'device-1',
            deleted: const Value(true),
            deletedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> insertDeletedNotebook({
    required String id,
    required String name,
  }) async {
    await db.into(db.notebooks).insert(
          NotebooksCompanion.insert(
            id: Value(id),
            name: name,
            colorSeed: '#FF0000',
            deleted: const Value(true),
            deletedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> insertDeletedTag({
    required String id,
    required String name,
  }) async {
    await db.into(db.tags).insert(
          TagsCompanion.insert(
            id: Value(id),
            name: name,
            colorSeed: '#2196F3',
            deleted: const Value(true),
            deletedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> insertDeletedAttachment({
    required String id,
    required String noteId,
    AttachmentType type = AttachmentType.image,
  }) async {
    // Need a note to reference — insert one if missing.
    await db.into(db.attachments).insert(
          AttachmentsCompanion.insert(
            id: Value(id),
            noteId: noteId,
            type: type,
            filePath: '/tmp/$id',
            deleted: const Value(true),
            deletedAt: Value(DateTime.now()),
          ),
        );
  }

  Widget buildTrash() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: TrashScreen()),
    );
  }

  group('Tab bar', () {
    testWidgets('shows 4 tabs: Notes, Notebooks, Tags, Attachments',
        (tester) async {
      await tester.pumpWidget(buildTrash());
      await tester.pumpAndSettle();

      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Notebooks'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Attachments'), findsOneWidget);
    });

    testWidgets('app bar shows Bin title', (tester) async {
      await tester.pumpWidget(buildTrash());
      await tester.pumpAndSettle();

      expect(find.text('Bin'), findsOneWidget);
    });
  });

  group('Notes tab', () {
    testWidgets('lists deleted notes with restore/destroy', (tester) async {
      await insertDeletedNote(id: 'dn-1', title: 'Deleted Note');

      await tester.pumpWidget(buildTrash());
      await tester.pumpAndSettle();

      expect(find.text('Deleted Note'), findsOneWidget);
      // Restore button
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedUndo02),
        findsWidgets,
      );
      // Destroy button
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedDelete01),
        findsWidgets,
      );
    });

    testWidgets('shows empty state when no deleted notes', (tester) async {
      await tester.pumpWidget(buildTrash());
      await tester.pumpAndSettle();

      expect(find.text('Nothing here yet'), findsWidgets);
    });
  });

  group('Notebooks tab', () {
    testWidgets('lists deleted notebooks with restore/destroy', (tester) async {
      await insertDeletedNotebook(id: 'dnb-1', name: 'Deleted Notebook');

      await tester.pumpWidget(buildTrash());
      await tester.pumpAndSettle();

      // Switch to Notebooks tab
      await tester.tap(find.text('Notebooks'));
      await tester.pumpAndSettle();

      expect(find.text('Deleted Notebook'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedUndo02),
        findsWidgets,
      );
    });
  });

  group('Tags tab', () {
    testWidgets('lists deleted tags with restore/destroy', (tester) async {
      await insertDeletedTag(id: 'dt-1', name: 'Deleted Tag');

      await tester.pumpWidget(buildTrash());
      await tester.pumpAndSettle();

      // Switch to Tags tab
      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();

      expect(find.text('Deleted Tag'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedUndo02),
        findsWidgets,
      );
    });
  });

  group('Attachments tab', () {
    testWidgets('lists deleted attachments with restore/destroy',
        (tester) async {
      // Need a note first for the FK constraint.
      await insertDeletedNote(id: 'note-for-att', title: 'Note');
      await insertDeletedAttachment(id: 'da-1', noteId: 'note-for-att');

      await tester.pumpWidget(buildTrash());
      await tester.pumpAndSettle();

      // Switch to Attachments tab
      await tester.tap(find.text('Attachments'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedUndo02),
        findsWidgets,
      );
    });
  });

  group('Restore', () {
    testWidgets('restore removes note from trash list', (tester) async {
      await insertDeletedNote(id: 'del-1', title: 'Restorable');

      await tester.pumpWidget(buildTrash());
      await tester.pumpAndSettle();

      // Tap restore on the first item
      await tester.tap(find
          .byWidgetPredicate(
              (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedUndo02)
          .first);
      await tester.pumpAndSettle();

      expect(find.text('Restorable'), findsNothing);
    });
  });

  group('Destroy', () {
    testWidgets('destroy shows confirmation, then permanently removes',
        (tester) async {
      await insertDeletedNote(id: 'del-1', title: 'Doomed');

      await tester.pumpWidget(buildTrash());
      await tester.pumpAndSettle();

      // Tap destroy
      await tester.tap(find
          .byWidgetPredicate(
              (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedDelete01)
          .first);
      await tester.pumpAndSettle();

      expect(find.text('Permanently Delete?'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Destroy'));
      await tester.pumpAndSettle();

      expect(find.text('Doomed'), findsNothing);
    });

    testWidgets('cancelling destroy keeps note', (tester) async {
      await insertDeletedNote(id: 'del-1', title: 'Safe');

      await tester.pumpWidget(buildTrash());
      await tester.pumpAndSettle();

      await tester.tap(find
          .byWidgetPredicate(
              (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedDelete01)
          .first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Safe'), findsOneWidget);
    });
  });

  group('Empty All', () {
    testWidgets('empty all shows total count and destroys everything',
        (tester) async {
      await insertDeletedNote(id: 'dn-1', title: 'Note A');
      await insertDeletedNote(id: 'dn-2', title: 'Note B');
      await insertDeletedNotebook(id: 'nb-1', name: 'Old Notebook');

      await tester.pumpWidget(buildTrash());
      await tester.pumpAndSettle();

      // The empty all FAB should be visible
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Tap it
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Should show confirmation with count
      expect(find.textContaining('Empty Bin'), findsWidgets);
      expect(find.textContaining('3'), findsWidgets);

      // Confirm
      await tester.tap(find.widgetWithText(FilledButton, 'Empty Bin'));
      await tester.pumpAndSettle();

      // Everything should be gone
      expect(find.text('Note A'), findsNothing);
      expect(find.text('Note B'), findsNothing);
      expect(find.text('Old Notebook'), findsNothing);
    });
  });
}

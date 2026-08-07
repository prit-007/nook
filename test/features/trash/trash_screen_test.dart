import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
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

  Widget buildTrash() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: TrashScreen()),
    );
  }

  testWidgets('renders app bar title', (tester) async {
    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();
    expect(find.text('Trash'), findsOneWidget);
  });

  testWidgets('shows empty state when no deleted notes', (tester) async {
    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();
    expect(find.text('Trash is empty'), findsOneWidget);
  });

  testWidgets('shows empty trash icon', (tester) async {
    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('displays deleted notes', (tester) async {
    await insertDeletedNote(id: 'del-1', title: 'Deleted note 1');
    await insertDeletedNote(id: 'del-2', title: 'Deleted note 2');

    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();

    expect(find.text('Deleted note 1'), findsOneWidget);
    expect(find.text('Deleted note 2'), findsOneWidget);
  });

  testWidgets('shows untitled for empty title', (tester) async {
    await insertDeletedNote(id: 'del-3', title: '');

    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();

    expect(find.text('Untitled'), findsOneWidget);
  });

  testWidgets('shows restore button for each note', (tester) async {
    await insertDeletedNote(id: 'del-1', title: 'Note');

    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.restore_from_trash_outlined), findsOneWidget);
  });

  testWidgets('shows permanent delete button for each note', (tester) async {
    await insertDeletedNote(id: 'del-1', title: 'Note');

    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.delete_forever_outlined), findsOneWidget);
  });

  testWidgets('restore removes note from trash list', (tester) async {
    await insertDeletedNote(id: 'del-1', title: 'Restorable');

    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.restore_from_trash_outlined));
    await tester.pump();
    await tester.pump();

    expect(find.text('Restorable'), findsNothing);
    expect(find.text('Trash is empty'), findsOneWidget);
  });

  testWidgets('permanent delete shows confirmation dialog', (tester) async {
    await insertDeletedNote(id: 'del-1', title: 'Doomed');

    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_forever_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Permanently delete?'), findsOneWidget);
    // Dialog content contains the title + warning
    expect(find.text('"Doomed" will be permanently deleted. This cannot be undone.'), findsOneWidget);
  });

  testWidgets('confirming permanent delete removes note', (tester) async {
    await insertDeletedNote(id: 'del-1', title: 'Doomed');

    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_forever_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Doomed'), findsNothing);
    expect(find.text('Trash is empty'), findsOneWidget);
  });

  testWidgets('cancelling permanent delete keeps note', (tester) async {
    await insertDeletedNote(id: 'del-1', title: 'Safe');

    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_forever_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Safe'), findsOneWidget);
  });

  testWidgets('empty trash button shows when notes exist', (tester) async {
    await insertDeletedNote(id: 'del-1', title: 'Note');

    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);
  });

  testWidgets('empty trash button not shown when empty', (tester) async {
    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.delete_sweep_outlined), findsNothing);
  });

  testWidgets('empty trash shows confirmation dialog', (tester) async {
    await insertDeletedNote(id: 'del-1', title: 'Note A');
    await insertDeletedNote(id: 'del-2', title: 'Note B');

    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Empty trash?'), findsOneWidget);
    expect(find.textContaining('2 notes'), findsOneWidget);
  });

  testWidgets('confirming empty trash removes all notes', (tester) async {
    await insertDeletedNote(id: 'del-1', title: 'Note A');
    await insertDeletedNote(id: 'del-2', title: 'Note B');

    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete all'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Trash is empty'), findsOneWidget);
  });

  testWidgets('shows relative time for deleted notes', (tester) async {
    await insertDeletedNote(id: 'del-1', title: 'Recent');

    await tester.pumpWidget(buildTrash());
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Deleted'), findsOneWidget);
  });
}

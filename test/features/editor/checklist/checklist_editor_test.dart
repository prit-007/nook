import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/checklist_item_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/checklist_editor.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;
  late ChecklistItemRepository repo;

  setUp(() async {
    db = createTestDb();
    repo = ChecklistItemRepository(db);

    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: const Value('note-1'),
            type: NoteType.checklist,
            title: const Value('My Checklist'),
            deviceOriginId: 'device-1',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildEditor({String noteId = 'note-1'}) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Scaffold(
          body: ChecklistEditor(noteId: noteId),
        ),
      ),
    );
  }

  testWidgets('renders empty state when no items', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.textContaining('No items'), findsOneWidget);
  });

  testWidgets('shows add item text field', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shows hint text in add field', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.text('Add item...'), findsOneWidget);
  });

  testWidgets('adds an item via text field', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('displays existing items', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'Item A');
    await repo.addItem(noteId: 'note-1', text: 'Item B');

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.text('Item A'), findsOneWidget);
    expect(find.text('Item B'), findsOneWidget);
  });

  testWidgets('checkbox is unchecked by default', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'Task');

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
  });

  testWidgets('tapping checkbox toggles checked state', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'Task');

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });

  testWidgets('shows item count', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'A');
    await repo.addItem(noteId: 'note-1', text: 'B');

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.text('0/2'), findsOneWidget);
  });

  testWidgets('shows singular item count', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'A');

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.text('0/1'), findsOneWidget);
  });

  testWidgets('shows progress indicator', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'Done');
    await repo.addItem(noteId: 'note-1', text: 'Not done');

    // Toggle first to checked
    final items = await repo.getItems('note-1');
    await repo.toggleChecked(items[0].id);

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('delete icon appears on item', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'Deletable');

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('tapping delete icon removes item', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'Delete me');

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Delete me'), findsNothing);
    expect(find.textContaining('No items'), findsOneWidget);
  });

  testWidgets('checked item shows strikethrough text', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'Done task');
    final items = await repo.getItems('note-1');
    await repo.toggleChecked(items[0].id);

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    final textWidget = tester.widget<Text>(find.text('Done task'));
    final decoration = textWidget.style?.decoration;
    expect(decoration, isNotNull);
    expect(decoration!.contains(TextDecoration.lineThrough), isTrue);
  });
}

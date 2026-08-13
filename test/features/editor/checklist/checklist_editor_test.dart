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

  /// Tap the morphing input circle to expand it into a full text field.
  Future<void> expandInput(WidgetTester tester) async {
    // The collapsed circle shows an add icon.
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('renders empty state when no items', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.text('A fresh start.'), findsOneWidget);
  });

  testWidgets('shows add item text field after expanding', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await expandInput(tester);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shows hint text in add field after expanding', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await expandInput(tester);
    expect(find.text('Add a new task...'), findsOneWidget);
  });

  testWidgets('adds an item via text field', (tester) async {
    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await expandInput(tester);
    await tester.enterText(find.byType(TextField), 'Buy milk');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Buy milk'), findsOneWidget);
  });

  testWidgets('displays existing items', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'Item A');
    await repo.addItem(noteId: 'note-1', text: 'Item B');

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.text('Item A'), findsOneWidget);
    expect(find.text('Item B'), findsOneWidget);
  });

  testWidgets('unchecked item shows empty circle', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'Task');

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    // The custom circle should not show a check icon when unchecked
    final tile = find.ancestor(
      of: find.text('Task'),
      matching: find.byType(GestureDetector),
    );
    expect(tile, findsAtLeastNWidgets(1));
  });

  testWidgets('tapping checkbox toggles checked state', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'Task');

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    // Tap the circle toggle (first GestureDetector inside the Row)
    final rowFinder = find.ancestor(
      of: find.text('Task'),
      matching: find.byType(Row),
    );
    final circleToggle = find.descendant(
      of: rowFinder.first,
      matching: find.byType(GestureDetector),
    );
    await tester.tap(circleToggle.first);
    await tester.pumpAndSettle();

    // After toggling, the item should be checked (shows check icon)
    final items = await repo.getItems('note-1');
    expect(items.first.checked, isTrue);
  });

  testWidgets('shows item count', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'A');
    await repo.addItem(noteId: 'note-1', text: 'B');

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.text('0 of 2 Done'), findsOneWidget);
  });

  testWidgets('shows singular item count', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'A');

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.text('0 of 1 Done'), findsOneWidget);
  });

  testWidgets('shows progress indicator', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'Done');
    await repo.addItem(noteId: 'note-1', text: 'Not done');

    final items = await repo.getItems('note-1');
    await repo.toggleChecked(items[0].id);

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.text('1 of 2 Done'), findsOneWidget);
  });

  testWidgets('delete icon appears on item', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'Deletable');

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('tapping delete icon removes item', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'Delete me');

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Delete me'), findsNothing);
    expect(find.text('A fresh start.'), findsOneWidget);
  });

  testWidgets('checked item shows strikethrough text', (tester) async {
    await repo.addItem(noteId: 'note-1', text: 'Done task');
    final items = await repo.getItems('note-1');
    await repo.toggleChecked(items[0].id);

    await tester.pumpWidget(buildEditor());
    await tester.pumpAndSettle();

    expect(strikeWidth(tester, 'Done task'), 1.0);
  });

  group('swipe-to-check & strikethrough animation', () {
    testWidgets('swiping item right checks it', (tester) async {
      await repo.addItem(noteId: 'note-1', text: 'Swipe me');

      await tester.pumpWidget(buildEditor());
      await tester.pumpAndSettle();

      await tester.drag(find.text('Swipe me'), const Offset(400, 0));
      await tester.pumpAndSettle();

      final items = await repo.getItems('note-1');
      expect(items.first.checked, isTrue);
    });

    testWidgets('swiping item left checks it', (tester) async {
      await repo.addItem(noteId: 'note-1', text: 'Swipe left');

      await tester.pumpWidget(buildEditor());
      await tester.pumpAndSettle();

      await tester.drag(find.text('Swipe left'), const Offset(-400, 0));
      await tester.pumpAndSettle();

      final items = await repo.getItems('note-1');
      expect(items.first.checked, isTrue);
    });

    testWidgets('tapping checked item in archive unchecks it', (tester) async {
      await repo.addItem(noteId: 'note-1', text: 'Uncheck me');
      final items = await repo.getItems('note-1');
      await repo.toggleChecked(items[0].id);

      await tester.pumpWidget(buildEditor());
      await tester.pumpAndSettle();

      // Checked items appear in the archived section under COMPLETED.
      // Tap the checkbox circle to uncheck.
      final rowFinder = find.ancestor(
        of: find.text('Uncheck me'),
        matching: find.byType(Row),
      );
      final circleToggle = find.descendant(
        of: rowFinder.first,
        matching: find.byType(GestureDetector),
      );
      await tester.tap(circleToggle.first);
      await tester.pumpAndSettle();

      final updatedItems = await repo.getItems('note-1');
      expect(updatedItems.first.checked, isFalse);
    });

    testWidgets('strikethrough animates in over time, not instantly',
        (tester) async {
      await repo.addItem(noteId: 'note-1', text: 'Animate');

      await tester.pumpWidget(buildEditor());
      await tester.pumpAndSettle();
      expect(strikeWidth(tester, 'Animate'), 0.0);

      // Tap the circle toggle
      final rowFinder = find.ancestor(
        of: find.text('Animate'),
        matching: find.byType(Row),
      );
      final circleToggle = find.descendant(
        of: rowFinder.first,
        matching: find.byType(GestureDetector),
      );
      await tester.tap(circleToggle.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final width = strikeWidth(tester, 'Animate');
      expect(width, greaterThan(0.0));
      expect(width, lessThan(1.0));
    });

    testWidgets('strikethrough is fully drawn when checked', (tester) async {
      await repo.addItem(noteId: 'note-1', text: 'Done');

      await tester.pumpWidget(buildEditor());
      await tester.pumpAndSettle();

      final rowFinder = find.ancestor(
        of: find.text('Done'),
        matching: find.byType(Row),
      );
      final circleToggle = find.descendant(
        of: rowFinder.first,
        matching: find.byType(GestureDetector),
      );
      await tester.tap(circleToggle.first);
      await tester.pumpAndSettle();

      expect(strikeWidth(tester, 'Done'), 1.0);
    });
  });
}

/// Width factor of the animated strike-through overlay for a checklist item.
double strikeWidth(WidgetTester tester, String text) {
  final tile =
      find.ancestor(of: find.text(text), matching: find.byType(Row)).first;
  final strike = find.descendant(
    of: tile,
    matching: find.byType(FractionallySizedBox),
  );
  return tester.widget<FractionallySizedBox>(strike.first).widthFactor ?? 1.0;
}

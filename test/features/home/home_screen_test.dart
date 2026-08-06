import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/home_screen.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildHome() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  Future<void> insertNote({
    required String title,
    NoteType type = NoteType.text,
    bool pinned = false,
  }) async {
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            title: Value(title),
            type: type,
            deviceOriginId: 'device-1',
            pinned: Value(pinned),
          ),
        );
  }

  testWidgets('renders the app title in AppBar', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();
    expect(find.text('Nook'), findsOneWidget);
  });

  testWidgets('shows a search text field', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('shows filter chips for note types', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Checklist'), findsOneWidget);
    expect(find.text('Doodle'), findsOneWidget);
  });

  testWidgets('shows a FAB for creating notes', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('displays notes in a grid', (tester) async {
    await insertNote(title: 'Note 1');
    await insertNote(title: 'Note 2');
    await insertNote(title: 'Note 3');

    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    expect(find.text('Note 1'), findsAtLeastNWidgets(1));
    expect(find.text('Note 2'), findsAtLeastNWidgets(1));
  });

  testWidgets('shows empty state when no notes exist', (tester) async {
    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    expect(find.textContaining('No notes'), findsOneWidget);
  });

  testWidgets('filter chips filter by note type', (tester) async {
    await insertNote(title: 'Text note', type: NoteType.text);
    await insertNote(title: 'Checklist note', type: NoteType.checklist);
    await insertNote(title: 'Another text', type: NoteType.text);

    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    expect(find.text('Text note'), findsAtLeastNWidgets(1));
    expect(find.text('Checklist note'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Checklist'));
    await tester.pumpAndSettle();

    expect(find.text('Text note'), findsNothing);
    expect(find.text('Checklist note'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('Text note'), findsAtLeastNWidgets(1));
    expect(find.text('Checklist note'), findsAtLeastNWidgets(1));
  });

  testWidgets('pinned note shows pin badge', (tester) async {
    await insertNote(title: 'Pinned note', pinned: true);

    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.push_pin), findsOneWidget);
  });

  testWidgets('search field filters notes by title', (tester) async {
    await insertNote(title: 'Grocery list');
    await insertNote(title: 'Meeting notes');
    await insertNote(title: 'Grocery budget');

    await tester.pumpWidget(buildHome());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Grocery');
    await tester.pumpAndSettle();

    expect(find.text('Grocery list'), findsAtLeastNWidgets(1));
    expect(find.text('Grocery budget'), findsAtLeastNWidgets(1));
    expect(find.text('Meeting notes'), findsNothing);
  });
}

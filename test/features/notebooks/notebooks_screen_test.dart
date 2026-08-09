import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/notebook_repository.dart';
import 'package:nook/features/notebooks/notebooks_screen.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildScreen() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: NotebooksScreen()),
    );
  }

  Future<void> insertNotebook({
    required String name,
    String colorSeed = '#FF5722',
  }) async {
    final repo = NotebookRepository(db);
    await repo.createNotebook(name: name, colorSeed: colorSeed);
  }

  testWidgets('renders app bar title', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    expect(find.text('Notebooks'), findsOneWidget);
  });

  testWidgets('shows empty state when no notebooks', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();
    expect(find.textContaining('No notebooks'), findsOneWidget);
  });

  testWidgets('displays notebooks in a grid', (tester) async {
    await insertNotebook(name: 'Work');
    await insertNotebook(name: 'Personal');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
  });

  testWidgets('FAB opens create notebook form', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Create Notebook'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('create notebook via form sheet', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Enter notebook name
    await tester.enterText(find.byType(TextField).first, 'New Notebook');
    await tester.pumpAndSettle();

    // Tap save button
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Notebook should appear in grid
    expect(find.text('New Notebook'), findsOneWidget);
  });

  testWidgets('long press shows delete option', (tester) async {
    await insertNotebook(name: 'Delete Me');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Delete Me'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Delete Me'));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('delete notebook removes it from grid', (tester) async {
    await insertNotebook(name: 'Gone');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Gone'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Gone'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Gone'), findsNothing);
  });
}

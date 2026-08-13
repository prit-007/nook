import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/features/tags/tags_screen.dart';

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
      child: const MaterialApp(home: TagsScreen()),
    );
  }

  Future<void> insertTag({
    required String name,
    String colorSeed = '#2196F3',
  }) async {
    final repo = TagRepository(db);
    await repo.createTag(name: name, colorSeed: colorSeed);
  }

  /// Pumps with a fixed number of frames. The empty-state animation loops
  /// forever, so `pumpAndSettle` would never settle while it is visible.
  Future<void> pumpFrames(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('renders app bar title', (tester) async {
    await tester.pumpWidget(buildScreen());
    await pumpFrames(tester);
    expect(find.text('Tags'), findsOneWidget);
  });

  testWidgets('shows empty state when no tags', (tester) async {
    await tester.pumpWidget(buildScreen());
    await pumpFrames(tester);
    expect(find.textContaining('No tags'), findsOneWidget);
  });

  testWidgets('displays tags as pills', (tester) async {
    await insertTag(name: 'important');
    await insertTag(name: 'todo');

    await tester.pumpWidget(buildScreen());
    await pumpFrames(tester);

    expect(find.text('important'), findsOneWidget);
    expect(find.text('todo'), findsOneWidget);
  });

  testWidgets('FAB opens create tag form', (tester) async {
    await tester.pumpWidget(buildScreen());
    await pumpFrames(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The headline "New Tag" (size 22) is the sheet title; the FAB label is
    // smaller. Assert the sheet is present via the name TextField.
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('create tag via form sheet', (tester) async {
    await tester.pumpWidget(buildScreen());
    await pumpFrames(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField).first, 'new-tag');
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Create Tag'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('new-tag'), findsOneWidget);
  });

  testWidgets('long press shows delete option', (tester) async {
    await insertTag(name: 'delete-me');

    await tester.pumpWidget(buildScreen());
    await pumpFrames(tester);

    await tester.longPress(find.text('delete-me'));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('delete tag removes it', (tester) async {
    await insertTag(name: 'removable');

    await tester.pumpWidget(buildScreen());
    await pumpFrames(tester);

    await tester.longPress(find.text('removable'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('removable'), findsNothing);
  });
}

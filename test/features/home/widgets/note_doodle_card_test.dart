import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/widgets/note_doodle_card.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  int counter = 0;

  Future<Note> createTestNote({
    String title = 'Test Note',
    bool pinned = false,
  }) async {
    final id = 'note-${++counter}';
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: Value(id),
            title: Value(title),
            type: NoteType.doodle,
            deviceOriginId: 'device-1',
            pinned: Value(pinned),
          ),
        );
    return (db.select(db.notes)..where((t) => t.id.equals(id))).getSingle();
  }

  Widget buildCard(Note note, {VoidCallback? onTap}) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Scaffold(
          body: NoteDoodleCard(note: note, onTap: onTap),
        ),
      ),
    );
  }

  group('NoteDoodleCard', () {
    testWidgets('displays note title', (tester) async {
      final note = await createTestNote(title: 'My Sketch');
      await tester.pumpWidget(buildCard(note));
      await tester.pump();

      expect(find.text('My Sketch'), findsOneWidget);
    });

    testWidgets('shows "Canvas Doodle" label', (tester) async {
      final note = await createTestNote(title: 'Art');
      await tester.pumpWidget(buildCard(note));
      await tester.pump();

      expect(find.text('Canvas Doodle'), findsOneWidget);
    });

    testWidgets('shows gesture icon in visual area', (tester) async {
      final note = await createTestNote(title: 'Art');
      await tester.pumpWidget(buildCard(note));
      await tester.pump();

      expect(find.byIcon(Icons.gesture_rounded), findsOneWidget);
    });

    testWidgets('shows pin icon when pinned', (tester) async {
      final note = await createTestNote(title: 'Pinned', pinned: true);
      await tester.pumpWidget(buildCard(note));
      await tester.pump();

      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    });

    testWidgets('does not show pin icon when not pinned', (tester) async {
      final note = await createTestNote(title: 'Not pinned', pinned: false);
      await tester.pumpWidget(buildCard(note));
      await tester.pump();

      expect(find.byIcon(Icons.push_pin_rounded), findsNothing);
    });

    testWidgets('shows "Untitled doodle" when title is empty', (tester) async {
      final note = await createTestNote(title: '');
      await tester.pumpWidget(buildCard(note));
      await tester.pump();

      expect(find.text('Untitled doodle'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      final note = await createTestNote(title: 'Tap me');
      await tester.pumpWidget(
        buildCard(note, onTap: () => tapped = true),
      );
      await tester.pump();

      await tester.tap(find.byType(NoteDoodleCard));
      expect(tapped, isTrue);
    });
  });
}

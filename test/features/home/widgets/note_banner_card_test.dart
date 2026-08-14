import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/widgets/note_banner_card.dart';

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
    NoteType type = NoteType.text,
    bool pinned = false,
    bool locked = false,
    String? colorSeed,
    String? plainText,
  }) async {
    final id = 'note-${++counter}';
    await db.into(db.notes).insert(
          NotesCompanion.insert(
            id: Value(id),
            title: Value(title),
            type: type,
            deviceOriginId: 'device-1',
            pinned: Value(pinned),
            locked: Value(locked),
            colorSeed: Value(colorSeed),
            plainText: Value(plainText),
          ),
        );
    return (db.select(db.notes)..where((t) => t.id.equals(id))).getSingle();
  }

  Widget buildCard(Note note, {VoidCallback? onTap}) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Scaffold(
          body: NoteBannerCard(note: note, onTap: onTap),
        ),
      ),
    );
  }

  group('NoteBannerCard', () {
    testWidgets('displays note title', (tester) async {
      final note = await createTestNote(title: 'My Banner');
      await tester.pumpWidget(buildCard(note));
      await tester.pump();

      expect(find.text('My Banner'), findsOneWidget);
    });

    testWidgets('shows type label', (tester) async {
      final note =
          await createTestNote(title: 'Tasks', type: NoteType.checklist);
      await tester.pumpWidget(buildCard(note));
      await tester.pump();

      expect(find.text('CHECKLIST'), findsOneWidget);
    });

    testWidgets('shows pin icon when pinned', (tester) async {
      final note = await createTestNote(title: 'Pinned', pinned: true);
      await tester.pumpWidget(buildCard(note));
      await tester.pump();

      expect(
          find.byWidgetPredicate(
              (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedPin),
          findsOneWidget);
    });

    testWidgets('does not show pin icon when not pinned', (tester) async {
      final note = await createTestNote(title: 'Not pinned', pinned: false);
      await tester.pumpWidget(buildCard(note));
      await tester.pump();

      expect(
          find.byWidgetPredicate(
              (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedPin),
          findsNothing);
    });

    testWidgets('shows lock icon when locked', (tester) async {
      final note = await createTestNote(title: 'Secret', locked: true);
      await tester.pumpWidget(buildCard(note));
      await tester.pump();

      expect(
          find.byWidgetPredicate(
              (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedLock),
          findsOneWidget);
    });

    testWidgets('shows plain text preview', (tester) async {
      final note = await createTestNote(
        title: 'Title',
        plainText: 'Preview text here',
      );
      await tester.pumpWidget(buildCard(note));
      await tester.pump();

      expect(find.text('Preview text here'), findsOneWidget);
    });

    testWidgets('shows "Untitled" when title is empty', (tester) async {
      final note = await createTestNote(title: '');
      await tester.pumpWidget(buildCard(note));
      await tester.pump();

      expect(find.text('Untitled'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      final note = await createTestNote(title: 'Tap me');
      await tester.pumpWidget(
        buildCard(note, onTap: () => tapped = true),
      );
      await tester.pump();

      await tester.tap(find.byType(NoteBannerCard));
      expect(tapped, isTrue);
    });
  });
}

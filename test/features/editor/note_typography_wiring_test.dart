import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/core/theme/note_theme_scope.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/widgets/note_options_sheet.dart';

void main() {
  late AppDatabase db;
  late NoteRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NoteRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Step 5 — Per-note typography persistence', () {
    test('new notes default to auto font style', () async {
      final note = await repo.createNote(
        title: 'Typography',
        type: NoteType.text,
        deviceOriginId: 'local',
      );
      expect(note.fontStyle, NoteFontStyle.auto.name);
    });

    test('updateNote persists fontStyle and round-trips', () async {
      final note = await repo.createNote(
        title: 'Typography',
        type: NoteType.text,
        deviceOriginId: 'local',
      );
      await repo.updateNote(note.id, fontStyle: NoteFontStyle.serif);
      expect((await repo.getNoteById(note.id))!.fontStyle,
          NoteFontStyle.serif.name);

      await repo.updateNote(note.id, fontStyle: NoteFontStyle.mono);
      expect((await repo.getNoteById(note.id))!.fontStyle,
          NoteFontStyle.mono.name);

      await repo.updateNote(note.id, fontStyle: NoteFontStyle.sans);
      expect((await repo.getNoteById(note.id))!.fontStyle,
          NoteFontStyle.sans.name);
    });

    test('updating other fields leaves fontStyle untouched', () async {
      final note = await repo.createNote(
        title: 'Typography',
        type: NoteType.text,
        deviceOriginId: 'local',
      );
      await repo.updateNote(note.id, fontStyle: NoteFontStyle.serif);
      await repo.updateNote(note.id, title: 'Renamed');
      expect((await repo.getNoteById(note.id))!.fontStyle,
          NoteFontStyle.serif.name);
    });
  });

  group('Step 5 — Note options sheet: typography picker', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildSheet({
      required NoteFontStyle current,
      required void Function(NoteFontStyle) onChanged,
    }) {
      return ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: NoteOptionsSheet(
              noteId: 'style-test-note',
              currentFontStyle: current,
              onFontStyleChanged: onChanged,
            ),
          ),
        ),
      );
    }

    Future<void> pumpSheet(
      WidgetTester tester, {
      required NoteFontStyle current,
      required void Function(NoteFontStyle) onChanged,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        buildSheet(current: current, onChanged: onChanged),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows a checkmark on the currently selected style',
        (tester) async {
      var changed = NoteFontStyle.auto;
      await pumpSheet(
        tester,
        current: NoteFontStyle.serif,
        onChanged: (s) => changed = s,
      );

      expect(find.text('Note style'), findsOneWidget);
      expect(find.text('Serif'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon &&
            w.icon == HugeIcons.strokeRoundedCheckmarkCircle02),
        findsOneWidget,
      );

      await tester.tap(find.text('Automatic').first);
      await tester.pumpAndSettle();

      expect(changed, NoteFontStyle.auto);
      expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon &&
            w.icon == HugeIcons.strokeRoundedCheckmarkCircle02),
        findsOneWidget,
      );
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/commands/command_registry.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_link_repository.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/reminder_repository.dart';
import 'package:nook/data/repositories/template_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/editor/widgets/backlinks_panel.dart';
import 'package:nook/features/home/search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Phase 6 — Editor depth', () {
    test('6.1a ReminderRepository.scheduleTaskDueDate creates task reminder',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final noteRepo = NoteRepository(db);
      final reminderRepo =
          ReminderRepository(db, scheduler: const NoopReminderScheduler());

      final note = await noteRepo.createNote(
        title: 'Sprint Tasks',
        type: NoteType.checklist,
        deviceOriginId: 'dev-1',
      );

      final due = DateTime.now().add(const Duration(days: 2));
      final reminder = await reminderRepo.scheduleTaskDueDate(
        noteId: note.id,
        taskText: 'Review PR #42',
        dueAt: due,
      );
      expect(reminder.noteId, note.id);
      expect(reminder.title, 'Review PR #42');
    });

    test('6.1b TemplateRepository creates idempotent daily note', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final repo = TemplateRepository(db);

      final date = DateTime(2026, 11, 27);
      final first = await repo.getOrCreateDailyNote(date: date);
      final second = await repo.getOrCreateDailyNote(date: date);
      expect(first.id, second.id);
      expect(first.title, '2026-11-27');
    });

    test('6.1c SavedSearchStore persists and deletes saved search queries',
        () async {
      SharedPreferences.setMockInitialValues({});
      await SavedSearchStore.saveQuery('argon2id');
      await SavedSearchStore.saveQuery('roadmap');
      expect(await SavedSearchStore.loadQueries(), ['roadmap', 'argon2id']);

      await SavedSearchStore.removeQuery('argon2id');
      expect(await SavedSearchStore.loadQueries(), ['roadmap']);
    });

    test(
        '6.1d buildNoteQuickSwitchCommands creates quick-switch commands for live notes',
        () {
      final notes = [
        Note(
          id: 'n-1',
          title: 'Design Doc',
          type: NoteType.text,
          pinned: false,
          locked: false,
          archived: false,
          deleted: false,
          syncVersion: 1,
          deviceOriginId: 'dev-1',
          fontStyle: 'auto',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        Note(
          id: 'n-2',
          title: 'Deleted Note',
          type: NoteType.text,
          pinned: false,
          locked: false,
          archived: false,
          deleted: true,
          syncVersion: 1,
          deviceOriginId: 'dev-1',
          fontStyle: 'auto',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      final commands = buildNoteQuickSwitchCommands(notes);
      expect(commands, hasLength(1));
      expect(commands.first.title, contains('Design Doc'));
      expect(commands.first.keywords, contains('n-1'));
    });

    testWidgets('6.1e BacklinkGraphView renders center node and linked nodes',
        (tester) async {
      const graph = BacklinkGraphData(
        centerTitle: 'Architecture',
        incoming: [
          NoteLinkHit(
            noteId: 'src-1',
            title: 'Security ADR',
            linkedNoteId: 'center',
            linkedTitle: 'Architecture',
          ),
        ],
        relatedTitles: ['Threat Model'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BacklinkGraphView(
              graph: graph,
              onSelectNote: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Architecture'), findsOneWidget);
      expect(find.text('Security ADR'), findsOneWidget);
      expect(find.text('Threat Model'), findsOneWidget);
    });
  });
}

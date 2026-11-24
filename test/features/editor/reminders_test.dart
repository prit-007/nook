import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/reminder_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/data/tables/reminders.dart';
import 'package:nook/features/editor/widgets/note_reminders_sheet.dart';

class _FakeReminderScheduler extends NoopReminderScheduler {
  final List<int> scheduled = [];
  final List<int> cancelled = [];

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime fireAt,
    required ReminderRepeat repeat,
  }) async {
    scheduled.add(notificationId);
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _FakeReminderScheduler scheduler;
  late ReminderRepository reminderRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    scheduler = _FakeReminderScheduler();
    reminderRepo = ReminderRepository(db, scheduler: scheduler);
  });

  tearDown(() async {
    await db.close();
  });

  group('Step 8 — Reminders UI: NoteRemindersSheet', () {
    testWidgets('Renders empty state and allows opening date/time picker flow',
        (tester) async {
      final note = await NoteRepository(db).createNote(
        title: 'Meeting Notes',
        type: NoteType.text,
        deviceOriginId: 'local',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NoteRemindersSheet(
                noteId: note.id,
                noteTitle: note.title,
                scheduler: scheduler,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('No reminders scheduled yet'), findsOneWidget);
      expect(find.text('Add reminder'), findsOneWidget);
    });

    testWidgets('Lists existing reminders with delete action using HugeIcon',
        (tester) async {
      final note = await NoteRepository(db).createNote(
        title: 'Task Reminder Note',
        type: NoteType.text,
        deviceOriginId: 'local',
      );

      final fireAt = DateTime.now().add(const Duration(days: 1));
      await reminderRepo.create(
        noteId: note.id,
        title: 'Follow up on task',
        fireAt: fireAt,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NoteRemindersSheet(
                noteId: note.id,
                noteTitle: note.title,
                scheduler: scheduler,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Follow up on task'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedDelete02),
        findsOneWidget,
      );

      // Tap delete
      await tester.tap(find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedDelete02));
      await tester.pumpAndSettle();

      expect(find.text('No reminders scheduled yet'), findsOneWidget);
    });
  });
}

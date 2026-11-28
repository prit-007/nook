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
import 'package:nook/features/reminders/reminders_screen.dart';

void main() {
  late AppDatabase db;
  late NoteRepository noteRepo;
  late ReminderRepository reminderRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    noteRepo = NoteRepository(db);
    reminderRepo = ReminderRepository(
      db,
      scheduler: const NoopReminderScheduler(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildScreen() {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(
        home: RemindersScreen(scheduler: NoopReminderScheduler()),
      ),
    );
  }

  group('RemindersScreen', () {
    testWidgets('shows empty state with HugeIcon when no reminders exist',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('No reminders yet'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedAlarmClock,
        ),
        findsWidgets,
      );
    });

    testWidgets('lists enabled reminders and deletes one with HugeIcon',
        (tester) async {
      final note = await noteRepo.createNote(
        title: 'Buy groceries',
        type: NoteType.text,
        deviceOriginId: 'local',
      );
      await reminderRepo.create(
        noteId: note.id,
        title: 'Buy groceries',
        fireAt: DateTime.now().add(const Duration(hours: 2)),
        repeat: ReminderRepeat.daily,
      );

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Buy groceries'), findsOneWidget);
      expect(find.text('Daily'), findsOneWidget);

      final deleteIcon = find.byWidgetPredicate(
        (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedDelete01,
      );
      expect(deleteIcon, findsOneWidget);

      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      expect(find.text('No reminders yet'), findsOneWidget);
      expect(await reminderRepo.allEnabled(), isEmpty);
    });

    testWidgets('can add a reminder from the add dialog', (tester) async {
      await noteRepo.createNote(
        title: 'Project Review',
        type: NoteType.text,
        deviceOriginId: 'local',
      );

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final addIcon = find.byWidgetPredicate(
        (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedAdd01,
      );
      expect(addIcon, findsWidgets);

      await tester.tap(addIcon.first);
      await tester.pumpAndSettle();

      expect(find.text('New Reminder'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        'Call Alice',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Call Alice'), findsOneWidget);
      final all = await reminderRepo.allEnabled();
      expect(all, hasLength(1));
      expect(all.first.title, 'Call Alice');
    });
  });
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/repositories/reminder_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/data/tables/reminders.dart';

class _RecordingScheduler implements ReminderScheduler {
  final scheduled = <(int, String, DateTime, ReminderRepeat)>[];
  final cancelled = <int>[];

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime fireAt,
    required ReminderRepeat repeat,
  }) async {
    scheduled.add((notificationId, title, fireAt, repeat));
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
  }

  @override
  Future<void> cancelForNote(String noteId) async {}

  @override
  Future<bool> requestPermissions() async => true;
}

void main() {
  late AppDatabase db;
  late NoteRepository noteRepo;
  late _RecordingScheduler scheduler;
  DateTime fixedNow() => DateTime(2026, 10, 4, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    noteRepo = NoteRepository(db);
    scheduler = _RecordingScheduler();
  });

  tearDown(() async {
    await db.close();
  });

  ReminderRepository repo() =>
      ReminderRepository(db, scheduler: scheduler, clock: fixedNow);

  group('nextFireAt', () {
    test('daily/weekly/monthly expand correctly', () {
      final base = DateTime(2026, 10, 4, 9, 30);
      expect(
          nextFireAt(base, ReminderRepeat.daily), DateTime(2026, 10, 5, 9, 30));
      expect(nextFireAt(base, ReminderRepeat.weekly),
          DateTime(2026, 10, 11, 9, 30));
      expect(nextFireAt(base, ReminderRepeat.monthly),
          DateTime(2026, 11, 4, 9, 30));
      // Month-end clamp: Jan 31 + 1 month → Feb 28/29
      final jan31 = DateTime(2026, 1, 31, 8);
      expect(
          nextFireAt(jan31, ReminderRepeat.monthly), DateTime(2026, 2, 28, 8));
    });
  });

  group('ReminderRepository', () {
    test('create schedules notification and stores row', () async {
      final note = await noteRepo.createNote(
        title: 'Call Mum',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      final fireAt = fixedNow().add(const Duration(hours: 4));
      final reminder = await repo().create(
        noteId: note.id,
        title: 'Call Mum back',
        body: 'She rang twice',
        fireAt: fireAt,
        repeat: ReminderRepeat.daily,
      );

      expect(reminder.noteId, note.id);
      expect(reminder.repeat, ReminderRepeat.daily.dbValue);
      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.scheduled.single.$1,
          ReminderRepository.notificationIdFor(reminder.id));
      expect(scheduler.scheduled.single.$2, 'Call Mum back');
      expect(scheduler.scheduled.single.$3, fireAt);
      expect(scheduler.scheduled.single.$4, ReminderRepeat.daily);
    });

    test('rejects past fireAt', () async {
      final note = await noteRepo.createNote(
        title: 'X',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      expect(
        () => repo().create(
          noteId: note.id,
          title: 'late',
          fireAt: fixedNow().subtract(const Duration(minutes: 1)),
        ),
        throwsArgumentError,
      );
    });

    test('delete cancels scheduler and removes row', () async {
      final note = await noteRepo.createNote(
        title: 'X',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      final reminder = await repo().create(
        noteId: note.id,
        title: 'temp',
        fireAt: fixedNow().add(const Duration(hours: 1)),
      );
      await repo().delete(reminder.id);
      expect(scheduler.cancelled,
          contains(ReminderRepository.notificationIdFor(reminder.id)));
      expect(await repo().forNote(note.id), isEmpty);
    });

    test('cancelAllForNote clears reminders for deleted note', () async {
      final note = await noteRepo.createNote(
        title: 'X',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      await repo().create(
        noteId: note.id,
        title: 'a',
        fireAt: fixedNow().add(const Duration(hours: 1)),
      );
      await repo().create(
        noteId: note.id,
        title: 'b',
        fireAt: fixedNow().add(const Duration(hours: 2)),
      );
      await repo().cancelAllForNote(note.id);
      expect(await repo().forNote(note.id), isEmpty);
      expect(scheduler.cancelled.length, 2);
    });

    test('setEnabled(false) cancels; true reschedules', () async {
      final note = await noteRepo.createNote(
        title: 'X',
        type: NoteType.text,
        deviceOriginId: 'd1',
      );
      final reminder = await repo().create(
        noteId: note.id,
        title: 'toggle',
        fireAt: fixedNow().add(const Duration(hours: 3)),
      );
      await repo().setEnabled(reminder.id, false);
      expect(scheduler.cancelled, isNotEmpty);

      final before = scheduler.scheduled.length;
      await repo().setEnabled(reminder.id, true);
      expect(scheduler.scheduled.length, before + 1);
    });

    test('schemaVersion is 7', () {
      expect(db.schemaVersion, 7);
    });
  });
}

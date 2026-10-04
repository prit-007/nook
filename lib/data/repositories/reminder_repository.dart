import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers/talker_provider.dart';
import '../database.dart';
import '../tables/reminders.dart';

/// Platform-agnostic reminder scheduling seam.
///
/// Production uses `flutter_local_notifications`; tests inject a fake.
abstract class ReminderScheduler {
  /// Schedules a one-shot or repeating local notification.
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime fireAt,
    required ReminderRepeat repeat,
  });

  Future<void> cancel(int notificationId);

  Future<void> cancelForNote(String noteId);

  /// Requests notification permission where the platform requires it.
  Future<bool> requestPermissions();
}

/// No-op scheduler for tests / platforms without notification support.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime fireAt,
    required ReminderRepeat repeat,
  }) async {}

  @override
  Future<void> cancel(int notificationId) async {}

  @override
  Future<void> cancelForNote(String noteId) async {}

  @override
  Future<bool> requestPermissions() async => false;
}

/// Pure helpers for reminder time math (unit-tested).
DateTime nextFireAt(DateTime from, ReminderRepeat repeat) {
  switch (repeat) {
    case ReminderRepeat.none:
      return from;
    case ReminderRepeat.daily:
      return from.add(const Duration(days: 1));
    case ReminderRepeat.weekly:
      return from.add(const Duration(days: 7));
    case ReminderRepeat.monthly:
      final month = from.month + 1;
      final year = from.year + (month > 12 ? 1 : 0);
      final normalizedMonth = month > 12 ? month - 12 : month;
      var day = from.day;
      // Clamp to end of month for short months.
      final daysInTarget = DateTime(year, normalizedMonth + 1, 0).day;
      if (day > daysInTarget) day = daysInTarget;
      return DateTime(
        year,
        normalizedMonth,
        day,
        from.hour,
        from.minute,
        from.second,
      );
  }
}

/// CRUD + scheduling for note reminders.
class ReminderRepository {
  ReminderRepository(
    this._db, {
    required ReminderScheduler scheduler,
    DateTime Function()? clock,
  })  : _scheduler = scheduler,
        _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final ReminderScheduler _scheduler;
  final DateTime Function() _clock;

  /// Deterministic notification id derived from the reminder row id.
  static int notificationIdFor(String reminderId) =>
      reminderId.hashCode & 0x7fffffff;

  Future<Reminder> create({
    required String noteId,
    required String title,
    String body = '',
    required DateTime fireAt,
    ReminderRepeat repeat = ReminderRepeat.none,
  }) async {
    if (!fireAt.isAfter(_clock())) {
      throw ArgumentError.value(fireAt, 'fireAt', 'must be in the future');
    }
    final id = const Uuid().v4();
    await _db.into(_db.reminders).insert(
          RemindersCompanion.insert(
            id: Value(id),
            noteId: noteId,
            title: Value(title),
            body: Value(body),
            fireAt: fireAt,
            repeat: Value(repeat.dbValue),
          ),
        );

    await _scheduler.schedule(
      notificationId: notificationIdFor(id),
      title: title,
      body: body.isEmpty ? 'Nook reminder' : body,
      fireAt: fireAt,
      repeat: repeat,
    );

    nookLog(
      NookLogKey.database,
      'Reminder created for note $noteId at $fireAt',
      LogLevel.info,
    );
    return (_db.select(_db.reminders)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<List<Reminder>> forNote(String noteId) {
    return (_db.select(_db.reminders)
          ..where((t) => t.noteId.equals(noteId) & t.enabled.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.fireAt)]))
        .get();
  }

  Future<List<Reminder>> allEnabled() {
    return (_db.select(_db.reminders)
          ..where((t) => t.enabled.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.fireAt)]))
        .get();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await (_db.update(_db.reminders)..where((t) => t.id.equals(id))).write(
      RemindersCompanion(enabled: Value(enabled)),
    );
    if (enabled) {
      final row = await (_db.select(_db.reminders)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row != null) {
        await _scheduler.schedule(
          notificationId: notificationIdFor(id),
          title: row.title,
          body: row.body.isEmpty ? 'Nook reminder' : row.body,
          fireAt: row.fireAt,
          repeat: ReminderRepeat.fromDb(row.repeat),
        );
      }
    } else {
      await _scheduler.cancel(notificationIdFor(id));
    }
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.reminders)..where((t) => t.id.equals(id))).go();
    await _scheduler.cancel(notificationIdFor(id));
  }

  /// Cancels all reminders for a note (e.g. when the note is deleted).
  Future<void> cancelAllForNote(String noteId) async {
    final rows = await (_db.select(_db.reminders)
          ..where((t) => t.noteId.equals(noteId)))
        .get();
    for (final row in rows) {
      await _scheduler.cancel(notificationIdFor(row.id));
    }
    await (_db.delete(_db.reminders)..where((t) => t.noteId.equals(noteId)))
        .go();
  }
}

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/sync_log_repository.dart';
import 'package:nook/data/tables/sync_log.dart';

void main() {
  late AppDatabase db;
  late SyncLogRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SyncLogRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncLogRepository', () {
    test('logSent inserts a sent entry and returns it', () async {
      final entry = await repo.logSent(
        deviceId: 'device-b',
        deviceName: 'Galaxy S24',
        noteId: 'note-1',
      );

      expect(entry.id, greaterThan(0));
      expect(entry.deviceId, 'device-b');
      expect(entry.deviceName, 'Galaxy S24');
      expect(entry.noteId, 'note-1');
      expect(entry.action, SyncAction.sent);
      expect(entry.timestamp, isNotNull);
    });

    test('logReceived inserts a received entry', () async {
      final entry = await repo.logReceived(
        deviceId: 'device-a',
        deviceName: 'Pixel 8',
        noteId: 'note-2',
      );

      expect(entry.action, SyncAction.received);
      expect(entry.deviceName, 'Pixel 8');
    });

    test('logConflict inserts a conflict entry', () async {
      final entry = await repo.logConflict(
        deviceId: 'device-b',
        deviceName: 'Galaxy S24',
        noteId: 'note-3',
      );

      expect(entry.action, SyncAction.conflict);
    });

    test('getRecentLogs returns entries ordered by timestamp desc', () async {
      await repo.logSent(
        deviceId: 'd1',
        deviceName: 'Phone 1',
        noteId: 'n1',
      );
      await repo.logReceived(
        deviceId: 'd2',
        deviceName: 'Phone 2',
        noteId: 'n2',
      );
      await repo.logConflict(
        deviceId: 'd1',
        deviceName: 'Phone 1',
        noteId: 'n3',
      );

      final logs = await repo.getRecentLogs();
      expect(logs.length, 3);
      // All three actions present
      final actions = logs.map((l) => l.action).toSet();
      expect(actions, containsAll([
        SyncAction.sent,
        SyncAction.received,
        SyncAction.conflict,
      ]));
    });

    test('getRecentLogs respects limit parameter', () async {
      for (var i = 0; i < 10; i++) {
        await repo.logSent(
          deviceId: 'd1',
          deviceName: 'Phone',
          noteId: 'n$i',
        );
      }

      final logs = await repo.getRecentLogs(limit: 5);
      expect(logs.length, 5);
    });

    test('getLogsForNote returns only logs for specific note', () async {
      await repo.logSent(deviceId: 'd1', deviceName: 'P1', noteId: 'n1');
      await repo.logSent(deviceId: 'd1', deviceName: 'P1', noteId: 'n2');
      await repo.logReceived(deviceId: 'd2', deviceName: 'P2', noteId: 'n1');

      final logs = await repo.getLogsForNote('n1');
      expect(logs.length, 2);
    });

    test('clearHistory removes all log entries', () async {
      await repo.logSent(deviceId: 'd1', deviceName: 'P1', noteId: 'n1');
      await repo.logSent(deviceId: 'd1', deviceName: 'P1', noteId: 'n2');

      await repo.clearHistory();

      final logs = await repo.getRecentLogs();
      expect(logs, isEmpty);
    });
  });
}

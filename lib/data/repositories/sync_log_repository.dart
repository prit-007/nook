import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sync_log.dart';

/// Repository for SyncLog table operations.
class SyncLogRepository {
  SyncLogRepository(this._db);

  final AppDatabase _db;

  /// Logs a sent sync action.
  Future<SyncLogData> logSent({
    required String deviceId,
    required String deviceName,
    required String noteId,
  }) async {
    final id = await _db.into(_db.syncLog).insert(
          SyncLogCompanion.insert(
            deviceId: deviceId,
            deviceName: deviceName,
            noteId: noteId,
            action: SyncAction.sent,
          ),
        );

    return (_db.select(_db.syncLog)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Logs a received sync action.
  Future<SyncLogData> logReceived({
    required String deviceId,
    required String deviceName,
    required String noteId,
  }) async {
    final id = await _db.into(_db.syncLog).insert(
          SyncLogCompanion.insert(
            deviceId: deviceId,
            deviceName: deviceName,
            noteId: noteId,
            action: SyncAction.received,
          ),
        );

    return (_db.select(_db.syncLog)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Logs a conflict sync action.
  Future<SyncLogData> logConflict({
    required String deviceId,
    required String deviceName,
    required String noteId,
  }) async {
    final id = await _db.into(_db.syncLog).insert(
          SyncLogCompanion.insert(
            deviceId: deviceId,
            deviceName: deviceName,
            noteId: noteId,
            action: SyncAction.conflict,
          ),
        );

    return (_db.select(_db.syncLog)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Returns recent log entries, ordered by timestamp descending.
  Future<List<SyncLogData>> getRecentLogs({int limit = 50}) async {
    return (_db.select(_db.syncLog)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .get();
  }

  /// Returns logs for a specific note.
  Future<List<SyncLogData>> getLogsForNote(String noteId) async {
    return (_db.select(_db.syncLog)
          ..where((t) => t.noteId.equals(noteId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
  }

  /// Clears all sync log entries.
  Future<void> clearHistory() async {
    await _db.delete(_db.syncLog).go();
  }
}

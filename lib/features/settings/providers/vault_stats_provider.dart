import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/providers/database_provider.dart';

/// Live vault usage: note / attachment counts plus on-disk foot print.
class VaultStats {
  const VaultStats({
    required this.noteCount,
    required this.attachmentCount,
    required this.dbBytes,
    required this.mediaBytes,
  });

  final int noteCount;
  final int attachmentCount;
  final int dbBytes;
  final int mediaBytes;

  int get totalBytes => dbBytes + mediaBytes;
}

final vaultStatsProvider = FutureProvider<VaultStats>((ref) async {
  final db = ref.watch(databaseProvider);

  final noteCountExpr = db.notes.id.count();
  final noteQuery = db.selectOnly(db.notes)
    ..where(db.notes.deleted.equals(false))
    ..addColumns([noteCountExpr]);
  final notesResult = await noteQuery.getSingle();
  final noteCountValue = notesResult.read(noteCountExpr) ?? 0;

  final attachmentCountExpr = db.attachments.id.count();
  final attachmentQuery = db.selectOnly(db.attachments)
    ..addColumns([attachmentCountExpr]);
  final attachmentResult = await attachmentQuery.getSingle();
  final attachmentCountValue = attachmentResult.read(attachmentCountExpr) ?? 0;

  var dbBytes = 0;
  var mediaBytes = 0;
  try {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(documentsDir.path, 'notes.db'));
    if (await dbFile.exists()) {
      dbBytes = await dbFile.length();
    }
    mediaBytes = await _directorySize(
      Directory(p.join(documentsDir.path, 'sync')),
    );
  } catch (_) {
    // In-memory/test databases have no platform storage; usage stays 0.
  }

  return VaultStats(
    noteCount: noteCountValue,
    attachmentCount: attachmentCountValue,
    dbBytes: dbBytes,
    mediaBytes: mediaBytes,
  );
});

Future<int> _directorySize(Directory directory) async {
  if (!await directory.exists()) return 0;
  var total = 0;
  await for (final entity in directory.list(recursive: true)) {
    if (entity is File) {
      try {
        total += await entity.length();
      } catch (_) {
        // Skip files that can't be measured.
      }
    }
  }
  return total;
}

/// Formats a byte count as a compact human string, e.g. `48 MB` / `920 kB`.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['kB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final rounded = value >= 100 ? value.round() : value.toStringAsFixed(1);
  return '$rounded ${units[unitIndex]}';
}

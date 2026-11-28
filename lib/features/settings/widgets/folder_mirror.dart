import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/providers/talker_provider.dart';
import '../../../data/database.dart';
import '../../../data/repositories/checklist_item_repository.dart';
import '../../../data/repositories/note_repository.dart';
import 'backup_handler.dart';
import 'bulk_export.dart';

/// Mirrors all live, **unlocked** notes as `.md` files into a user-selected
/// directory so external tools (e.g., Syncthing, Nextcloud) can sync them
/// without libp2p.
class FolderMirrorService {
  FolderMirrorService(this._db);

  final AppDatabase _db;

  Future<int> mirrorToDirectory(Directory targetDir) async {
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final noteRepo = NoteRepository(_db);
    final checklistRepo = ChecklistItemRepository(_db);
    final notes = (await noteRepo.getAllNotes())
        .where((n) => !n.locked && !n.deleted)
        .toList();

    final expectedNames = <String>{};
    for (final note in notes) {
      final items = await checklistRepo.getItems(note.id);
      final md = renderNoteMarkdown(note, items);
      final safeBase = note.title.trim().isEmpty
          ? note.id
          : note.title
              .trim()
              .replaceAll(RegExp(r'[^\w\s-]'), '')
              .replaceAll(RegExp(r'\s+'), '_');
      final fileName = '${safeBase}_${note.id.substring(0, 8)}.md';
      expectedNames.add(fileName);
      final file = File(p.join(targetDir.path, fileName));
      final tmpFile = File('${file.path}.tmp');
      await tmpFile.writeAsString(md, flush: true);
      await tmpFile.rename(file.path);
    }

    // Prune stale .md files for deleted or newly locked notes.
    await for (final entity in targetDir.list()) {
      if (entity is File && entity.path.endsWith('.md')) {
        final name = p.basename(entity.path);
        if (!expectedNames.contains(name)) {
          await entity.delete();
        }
      }
    }

    nookLog(
      NookLogKey.database,
      'Mirrored ${notes.length} unlocked note(s) to ${targetDir.path}',
      LogLevel.info,
    );
    return notes.length;
  }

  /// Writes an encrypted `.nookbackup` change snapshot into [targetDir] for
  /// external folder sync (e.g. Syncthing), keeping at most [maxSnapshots].
  Future<File> mirrorEncryptedSnapshot(
    Directory targetDir, {
    required String password,
    int maxSnapshots = 3,
    int argon2Memory = 19456,
    int argon2Iterations = 2,
  }) async {
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final handler = BackupHandler(
      _db,
      argon2Memory: argon2Memory,
      argon2Iterations: argon2Iterations,
    );
    final file = await handler.createEncryptedBackup(
      password: password,
      outputDirectory: targetDir,
    );

    final backups = targetDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.nookbackup'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    for (var i = maxSnapshots; i < backups.length; i++) {
      await backups[i].delete();
    }
    return file;
  }

  /// Imports any encrypted `.nookbackup` change files from [sourceDir]
  /// idempotently (safe under late or duplicate file arrivals).
  Future<int> importEncryptedSnapshots(
    Directory sourceDir, {
    required String password,
    int argon2Memory = 19456,
    int argon2Iterations = 2,
  }) async {
    if (!await sourceDir.exists()) return 0;
    final handler = BackupHandler(
      _db,
      argon2Memory: argon2Memory,
      argon2Iterations: argon2Iterations,
    );
    final backups = sourceDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.nookbackup'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    var totalRestored = 0;
    for (final file in backups) {
      totalRestored += await handler.restoreEncryptedBackup(
        backupFile: file,
        password: password,
      );
    }
    return totalRestored;
  }
}

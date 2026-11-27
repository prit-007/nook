import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/providers/talker_provider.dart';
import '../../../core/security/kdf.dart';
import '../../../data/database.dart';
import '../../../data/repositories/checklist_item_repository.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../data/repositories/notebook_repository.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../data/tables/notes.dart';

/// Thrown when decrypting a `.nookbackup` file fails due to a wrong password
/// or tampered ciphertext/MAC.
class BackupAuthenticationException implements Exception {
  const BackupAuthenticationException([
    this.message = 'Incorrect backup password or corrupted backup file.',
  ]);
  final String message;

  @override
  String toString() => 'BackupAuthenticationException: $message';
}

/// Creates and restores encrypted `.nookbackup` archives using Argon2id + AES-256-GCM.
class BackupHandler {
  BackupHandler(
    this._db, {
    this.argon2Memory = defaultArgon2Memory,
    this.argon2Iterations = defaultArgon2Iterations,
    this.argon2Parallelism = defaultArgon2Parallelism,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final int argon2Memory;
  final int argon2Iterations;
  final int argon2Parallelism;
  final DateTime Function() _clock;
  final AesGcm _aesGcm = AesGcm.with256bits();

  Future<File> createEncryptedBackup({
    required String password,
    Directory? outputDirectory,
  }) async {
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'must not be empty');
    }

    final noteRepo = NoteRepository(_db);
    final nbRepo = NotebookRepository(_db);
    final tagRepo = TagRepository(_db);
    final checklistRepo = ChecklistItemRepository(_db);

    final notebooks = await nbRepo.getAllNotebooks();
    final notes = await noteRepo.getAllNotes();

    final noteMaps = <Map<String, dynamic>>[];
    for (final n in notes) {
      final items = await checklistRepo.getItems(n.id);
      final tags = await tagRepo.getTagsForNote(n.id);
      noteMaps.add({
        'id': n.id,
        'title': n.title,
        'type': n.type.name,
        'deltaContent': n.deltaContent,
        'plainText': n.plainText,
        'colorSeed': n.colorSeed,
        'fontStyle': n.fontStyle,
        'pinned': n.pinned,
        'locked': n.locked,
        'archived': n.archived,
        'notebookId': n.notebookId,
        'syncVersion': n.syncVersion,
        'deviceOriginId': n.deviceOriginId,
        'createdAt': n.createdAt.millisecondsSinceEpoch,
        'updatedAt': n.updatedAt.millisecondsSinceEpoch,
        'checklistItems': [
          for (final item in items)
            {
              'id': item.id,
              'text': item.itemText,
              'checked': item.checked,
              'sortOrder': item.sortOrder,
            }
        ],
        'tags': [for (final t in tags) t.name],
      });
    }

    final payloadJson = jsonEncode({
      'format': 'nookbackup',
      'version': 2,
      'exportedAt': _clock().toIso8601String(),
      'notebooks': [
        for (final nb in notebooks)
          {
            'id': nb.id,
            'name': nb.name,
            'icon': nb.icon,
            'colorSeed': nb.colorSeed,
            'sortOrder': nb.sortOrder,
            'parentId': nb.parentId,
          }
      ],
      'notes': noteMaps,
    });

    final salt = generateSalt();
    final keyBytes = await argon2idDeriveBytes(
      password: password,
      salt: utf8.encode(salt),
      memory: argon2Memory,
      iterations: argon2Iterations,
      parallelism: argon2Parallelism,
      keyLength: 32,
    );

    final secretKey = SecretKey(keyBytes);
    final nonce = _aesGcm.newNonce();
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(payloadJson),
      secretKey: secretKey,
      nonce: nonce,
    );

    final envelope = jsonEncode({
      'v': 2,
      'kdf':
          '${argon2idPrefix}m=$argon2Memory,t=$argon2Iterations,p=$argon2Parallelism',
      'salt': salt,
      'nonce': base64Url.encode(secretBox.nonce),
      'ciphertext': base64Url.encode(secretBox.cipherText),
      'mac': base64Url.encode(secretBox.mac.bytes),
    });

    final dir = outputDirectory ?? await getApplicationDocumentsDirectory();
    final stamp = _clock().toIso8601String().replaceAll(':', '-');
    final file = File(p.join(dir.path, 'nook-backup-$stamp.nookbackup'));
    await file.writeAsString(envelope, flush: true);

    nookLog(
      NookLogKey.security,
      'Created encrypted .nookbackup (${notes.length} notes)',
      LogLevel.info,
    );
    return file;
  }

  Future<int> restoreEncryptedBackup({
    required File backupFile,
    required String password,
  }) async {
    final raw = await backupFile.readAsString();
    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupAuthenticationException('Invalid backup format.');
    }

    final kdf = envelope['kdf'] as String? ?? '';
    if (!kdf.startsWith(argon2idPrefix)) {
      throw const BackupAuthenticationException('Unsupported backup KDF.');
    }
    final params = parseArgon2idParams(kdf.substring(argon2idPrefix.length));
    if (params == null) {
      throw const BackupAuthenticationException('Malformed KDF parameters.');
    }

    final salt = envelope['salt'] as String;
    final keyBytes = await argon2idDeriveBytes(
      password: password,
      salt: utf8.encode(salt),
      memory: params.memory,
      iterations: params.iterations,
      parallelism: params.parallelism,
      keyLength: 32,
    );

    final box = SecretBox(
      base64Url.decode(envelope['ciphertext'] as String),
      nonce: base64Url.decode(envelope['nonce'] as String),
      mac: Mac(base64Url.decode(envelope['mac'] as String)),
    );

    final String plaintext;
    try {
      final clear = await _aesGcm.decrypt(box, secretKey: SecretKey(keyBytes));
      plaintext = utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const BackupAuthenticationException();
    } catch (_) {
      throw const BackupAuthenticationException();
    }

    final data = jsonDecode(plaintext) as Map<String, dynamic>;
    final nbRepo = NotebookRepository(_db);
    final noteRepo = NoteRepository(_db);
    final tagRepo = TagRepository(_db);
    final checklistRepo = ChecklistItemRepository(_db);

    final notebooks =
        (data['notebooks'] as List? ?? []).cast<Map<String, dynamic>>();
    for (final nb in notebooks) {
      final id = nb['id'] as String;
      if (await nbRepo.getNotebookById(id) == null) {
        await nbRepo.createNotebookWithId(
          id,
          name: nb['name'] as String,
          colorSeed: nb['colorSeed'] as String? ?? '#4CAF50',
          icon: nb['icon'] as String? ?? 'folder',
          parentId: nb['parentId'] as String?,
        );
      }
    }

    final notes = (data['notes'] as List? ?? []).cast<Map<String, dynamic>>();
    var restored = 0;
    for (final n in notes) {
      final id = n['id'] as String;
      if (await noteRepo.getNoteById(id) != null) continue;

      final type = NoteType.values.firstWhere(
        (t) => t.name == n['type'],
        orElse: () => NoteType.text,
      );
      await noteRepo.createNote(
        id: id,
        title: n['title'] as String? ?? '',
        type: type,
        deviceOriginId: n['deviceOriginId'] as String? ?? 'backup-restore',
        colorSeed: n['colorSeed'] as String?,
        deltaContent: n['deltaContent'] as String?,
        plainText: n['plainText'] as String?,
        notebookId: n['notebookId'] as String?,
        syncVersion: n['syncVersion'] as int? ?? 1,
        createdAt: n['createdAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(n['createdAt'] as int)
            : null,
      );

      await noteRepo.updateNote(
        id,
        pinned: n['pinned'] as bool?,
        locked: n['locked'] as bool?,
        updatedAt: n['updatedAt'] is int
            ? DateTime.fromMillisecondsSinceEpoch(n['updatedAt'] as int)
            : null,
      );
      if (n['archived'] == true) {
        await (_db.update(_db.notes)..where((t) => t.id.equals(id)))
            .write(const NotesCompanion(archived: Value(true)));
      }

      final items =
          (n['checklistItems'] as List? ?? []).cast<Map<String, dynamic>>();
      for (final item in items) {
        await checklistRepo.addItem(
          noteId: id,
          text: item['text'] as String,
          checked: item['checked'] as bool? ?? false,
        );
      }

      final tags = (n['tags'] as List? ?? []).cast<String>();
      for (final tag in tags) {
        await tagRepo.assignTagByName(id, tag);
      }
      restored++;
    }

    nookLog(
      NookLogKey.security,
      'Restored $restored notes from encrypted .nookbackup',
      LogLevel.info,
    );
    return restored;
  }
}

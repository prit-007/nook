import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/note_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/settings/widgets/backup_handler.dart';

void main() {
  group('Backup v1 decoder rejection tests (Phase 2.1)', () {
    test(
        'rejects wrong password, tampered ciphertext, tampered MAC, and truncated file',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      await NoteRepository(db).createNote(
        title: 'Golden Backup Note',
        type: NoteType.text,
        deviceOriginId: 'dev-1',
        plainText: 'Golden content',
      );

      final dir = await Directory.systemTemp.createTemp('nook_backup_dec_');
      addTearDown(() => dir.delete(recursive: true));

      final handler = BackupHandler(
        db,
        argon2Memory: 1024,
        argon2Iterations: 1,
      );
      final file = await handler.createEncryptedBackup(
        password: 'golden-password',
        outputDirectory: dir,
      );

      final targetDb = createTestDatabase();
      addTearDown(targetDb.close);
      final targetHandler = BackupHandler(
        targetDb,
        argon2Memory: 1024,
        argon2Iterations: 1,
      );

      // 1. Wrong password
      await expectLater(
        () => targetHandler.restoreEncryptedBackup(
          backupFile: file,
          password: 'wrong-password',
        ),
        throwsA(isA<BackupAuthenticationException>()),
      );

      // 2. Tampered ciphertext
      final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final tamperedCt = Map<String, dynamic>.from(map)
        ..['ciphertext'] = base64Url.encode([1, 2, 3, 4, 5]);
      final tamperedCtFile = File('${dir.path}/tampered_ct.nookbackup')
        ..writeAsStringSync(jsonEncode(tamperedCt));
      await expectLater(
        () => targetHandler.restoreEncryptedBackup(
          backupFile: tamperedCtFile,
          password: 'golden-password',
        ),
        throwsA(isA<BackupAuthenticationException>()),
      );

      // 3. Tampered MAC
      final tamperedMac = Map<String, dynamic>.from(map)
        ..['mac'] = base64Url.encode(List<int>.filled(16, 0));
      final tamperedMacFile = File('${dir.path}/tampered_mac.nookbackup')
        ..writeAsStringSync(jsonEncode(tamperedMac));
      await expectLater(
        () => targetHandler.restoreEncryptedBackup(
          backupFile: tamperedMacFile,
          password: 'golden-password',
        ),
        throwsA(isA<BackupAuthenticationException>()),
      );

      // 4. Truncated file
      final raw = file.readAsStringSync();
      final truncatedFile = File('${dir.path}/truncated.nookbackup')
        ..writeAsStringSync(raw.substring(0, raw.length ~/ 2));
      await expectLater(
        () => targetHandler.restoreEncryptedBackup(
          backupFile: truncatedFile,
          password: 'golden-password',
        ),
        throwsA(isA<BackupAuthenticationException>()),
      );
    });
  });
}

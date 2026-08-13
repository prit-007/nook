import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/providers/talker_provider.dart';
import 'tables/notebooks.dart';
import 'tables/notes.dart';
import 'tables/checklist_items.dart';
import 'tables/attachments.dart';
import 'tables/tags.dart';
import 'tables/note_tags.dart';
import 'tables/sync_log.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Notebooks,
  Notes,
  ChecklistItems,
  Attachments,
  Tags,
  NoteTags,
  SyncLog,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE VIRTUAL TABLE notes_fts USING fts5(id UNINDEXED, title, plainText)',
          );
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );
}

/// Opens an in-memory database for testing.
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

const _secureStorage = FlutterSecureStorage();
const _keyStorageKey = 'db_encryption_key';

String _generateRandomKey(int byteLength) {
  final random = Random.secure();
  final bytes = List<int>.generate(byteLength, (_) => random.nextInt(256));
  return base64.encode(bytes);
}

Future<String> _readOrCreateEncryptionKey() async {
  try {
    final existing = await _secureStorage.read(key: _keyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      nookLog(
        NookLogKey.security,
        'DB encryption key read from keystore',
        LogLevel.debug,
      );
      return existing;
    }
  } on Exception {
    nookLog(
      NookLogKey.security,
      'DB encryption key read failed; generating a new one',
      LogLevel.warning,
    );
  }

  final key = _generateRandomKey(32);
  await _secureStorage.write(key: _keyStorageKey, value: key);
  nookLog(NookLogKey.security, 'DB encryption key generated', LogLevel.info);
  return key;
}

/// Opens the production encrypted database.
///
/// Requires the `sqlite3` build hook to bundle SQLCipher (see `pubspec.yaml`,
/// `hooks.user_defines.sqlite3.source = sqlcipher`) so that `PRAGMA key` is
/// understood by the underlying SQLite binary. `flutter_secure_storage`
/// persists the encryption key in the platform keystore.
///
/// The biometric gate (`local_auth`) should be checked by the app layer
/// before calling this function, per ADR 0005.
Future<AppDatabase> openEncryptedDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(dir.path, 'notes.db'));
  nookLog(
    NookLogKey.database,
    'Opening encrypted DB at ${dbFile.path}',
    LogLevel.info,
  );

  final key = await _readOrCreateEncryptionKey();

  return AppDatabase(
    NativeDatabase.createInBackground(
      dbFile,
      setup: (database) {
        database.execute("PRAGMA key = '$key';");
        database.execute('PRAGMA cipher_page_size = 4096;');
        database.execute('PRAGMA journal_mode = WAL;');
      },
      enableMigrations: true,
    ),
  );
}

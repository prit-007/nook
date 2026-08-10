import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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
      return existing;
    }
  } on Exception {
    // Fall through to generate a new key on read failure.
  }

  final key = _generateRandomKey(32);
  try {
    await _secureStorage.write(key: _keyStorageKey, value: key);
  } on Exception {
    // Key is in memory; we'll use it for this session even if persistent
    // storage write fails. Next launch will generate a new key.
  }
  return key;
}

/// Opens the production encrypted database.
///
/// Requires:
/// - `sqlcipher_flutter_libs` (or the hooks-based sqlite3 + SQLCipher build)
///   so that `PRAGMA key` is understood by the underlying SQLite binary.
/// - `flutter_secure_storage` to persist the encryption key in the platform
///   keystore.
///
/// The biometric gate (`local_auth`) should be checked by the app layer
/// before calling this function, per ADR 0005.
Future<AppDatabase> openEncryptedDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(dir.path, 'notes.db'));

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

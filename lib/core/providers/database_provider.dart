import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nook/data/database.dart';

/// In-memory database for testing and development.
/// Will be replaced with encrypted DB in Phase 0.4.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(NativeDatabase.memory());
  ref.onDispose(() => db.close());
  return db;
});

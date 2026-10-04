import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key-value seam over platform secure storage.
///
/// Tests inject an in-memory store; production uses [FlutterSecureKeyValueStore].
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Production store backed by `flutter_secure_storage`.
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore(
      [this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// In-memory store for unit tests.
class InMemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  Map<String, String> get debugData => Map.unmodifiable(_data);
}

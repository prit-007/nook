import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_libp2p/core/crypto/ed25519.dart'
    show generateEd25519KeyPairFromSeed;
import 'package:dart_libp2p/core/crypto/keys.dart' show KeyPair;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/providers/talker_provider.dart';

/// Storage abstraction so unit tests can inject an in-memory fake instead of
/// the platform keystore-backed [FlutterSecureStorage].
abstract class SeedStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Keystore-backed implementation of [SeedStorage].
class SecureSeedStorage implements SeedStorage {
  const SecureSeedStorage();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// An in-memory [SeedStorage] for tests.
class InMemorySeedStorage implements SeedStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Persists the device's 32-byte Ed25519 seed in the platform keystore so the
/// libp2p identity (peer id) is stable across app restarts.
///
/// The seed is generated once on first use and reused afterwards, giving every
/// Nook install a permanent device id derived from the seed (pattern mirrors
/// `pin_provider.dart` — raw secrets never leave the keystore).
class IdentityStore {
  IdentityStore({SeedStorage? storage})
      : _storage = storage ?? const SecureSeedStorage();

  static const String seedKey = 'sync_libp2p_ed25519_seed';

  final SeedStorage _storage;
  Uint8List? _cachedSeed;

  /// Serializes concurrent callers so only one seed is generated/stored.
  Completer<Uint8List>? _pending;

  /// Returns the 32-byte Ed25519 seed, generating and persisting it on first
  /// use. The result is cached in memory for the process lifetime.
  ///
  /// Thread-safe: concurrent callers share a single in-flight
  /// [Completer] so two callers cannot race to generate different seeds.
  Future<Uint8List> getOrCreateSeed() async {
    if (_cachedSeed != null) return _cachedSeed!;

    if (_pending != null && !_pending!.isCompleted) {
      return _pending!.future;
    }

    _pending = Completer<Uint8List>();
    try {
      final stored = await _storage.read(seedKey);
      final seed = stored != null ? _decodeSeed(stored) : _generateSeed();

      if (stored == null) {
        await _storage.write(seedKey, _encodeSeed(seed));
        nookLog(
            NookLogKey.sync, 'Device identity seed generated', LogLevel.info);
      } else {
        nookLog(NookLogKey.sync, 'Device identity seed loaded', LogLevel.debug);
      }

      _cachedSeed = seed;
      _pending!.complete(seed);
      return seed;
    } catch (e) {
      _pending!.completeError(e);
      rethrow;
    } finally {
      _pending = null;
    }
  }

  /// Derives a deterministic libp2p [KeyPair] from the persisted seed.
  Future<KeyPair> getKeyPair() async {
    final seed = await getOrCreateSeed();
    return generateEd25519KeyPairFromSeed(seed);
  }

  /// Resets the stored seed (used to clear sync identity).
  Future<void> clear() async {
    await _storage.delete(seedKey);
    _cachedSeed = null;
    _pending = null;
    nookLog(NookLogKey.sync, 'Device identity reset', LogLevel.info);
  }

  static Uint8List _generateSeed() {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(32, (_) => rng.nextInt(256)),
    );
  }

  /// Seeds are stored base64url-encoded so they round-trip the keystore
  /// without byte corruption.
  static String _encodeSeed(Uint8List seed) => base64Url.encode(seed);

  static Uint8List _decodeSeed(String stored) =>
      Uint8List.fromList(base64Url.decode(stored));
}

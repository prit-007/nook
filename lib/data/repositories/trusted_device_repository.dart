import 'package:drift/drift.dart';
import '../database.dart';

/// Repository for managing trusted peer devices and auto-sync permissions.
class TrustedDeviceRepository {
  TrustedDeviceRepository(this._db);

  final AppDatabase _db;

  /// Returns all trusted devices, ordered by [trustedAt] descending.
  Future<List<TrustedDevice>> getTrustedDevices() async {
    return (_db.select(_db.trustedDevices)
          ..orderBy([(t) => OrderingTerm.desc(t.trustedAt)]))
        .get();
  }

  /// Watches all trusted devices for real-time UI updates.
  Stream<List<TrustedDevice>> watchTrustedDevices() {
    return (_db.select(_db.trustedDevices)
          ..orderBy([(t) => OrderingTerm.desc(t.trustedAt)]))
        .watch();
  }

  /// Finds a device by its libp2p peer id.
  Future<TrustedDevice?> getTrustedDeviceByPeerId(String peerId) async {
    return (_db.select(_db.trustedDevices)
          ..where((t) => t.peerId.equals(peerId)))
        .getSingleOrNull();
  }

  /// Whether a peer is known and allowed to auto-sync.
  Future<bool> isDeviceTrusted(String peerId) async {
    final device = await getTrustedDeviceByPeerId(peerId);
    return device != null && device.autoSyncEnabled;
  }

  /// Inserts a new trusted device or updates an existing record if [peerId] already exists.
  Future<TrustedDevice> addOrUpdateTrustedDevice({
    required String peerId,
    required String deviceName,
    String? publicKey,
    bool autoSyncEnabled = true,
  }) async {
    final existing = await getTrustedDeviceByPeerId(peerId);
    if (existing != null) {
      final companion = TrustedDevicesCompanion(
        deviceName: Value(deviceName),
        publicKey: publicKey != null
            ? Value(publicKey)
            : (existing.publicKey == null
                ? const Value.absent()
                : Value(existing.publicKey)),
        autoSyncEnabled: Value(autoSyncEnabled),
      );
      await (_db.update(_db.trustedDevices)
            ..where((t) => t.peerId.equals(peerId)))
          .write(companion);
      return (await getTrustedDeviceByPeerId(peerId))!;
    }

    await _db.into(_db.trustedDevices).insert(
          TrustedDevicesCompanion.insert(
            peerId: peerId,
            deviceName: deviceName,
            publicKey: Value(publicKey),
            autoSyncEnabled: Value(autoSyncEnabled),
            trustedAt: Value(DateTime.now()),
          ),
        );
    return (await getTrustedDeviceByPeerId(peerId))!;
  }

  /// Updates the [lastSyncedAt] timestamp when a sync session finishes with this peer.
  Future<void> updateLastSynced(String peerId, DateTime timestamp) async {
    await (_db.update(_db.trustedDevices)
          ..where((t) => t.peerId.equals(peerId)))
        .write(TrustedDevicesCompanion(lastSyncedAt: Value(timestamp)));
  }

  /// Enables or disables auto-sync for a trusted peer.
  Future<void> setAutoSyncEnabled(String peerId, bool enabled) async {
    await (_db.update(_db.trustedDevices)
          ..where((t) => t.peerId.equals(peerId)))
        .write(TrustedDevicesCompanion(autoSyncEnabled: Value(enabled)));
  }

  /// Removes a device from the trusted devices list.
  Future<void> untrustDevice(String peerId) async {
    await (_db.delete(_db.trustedDevices)
          ..where((t) => t.peerId.equals(peerId)))
        .go();
  }
}

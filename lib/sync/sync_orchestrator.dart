import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/platform/nearby_permissions.dart';
import '../core/platform/wifi_direct.dart';
import '../core/providers/database_provider.dart';
import '../core/providers/talker_provider.dart';
import '../data/repositories/attachment_repository.dart';
import '../data/repositories/note_repository.dart';
import '../data/repositories/notebook_repository.dart';
import '../data/repositories/sync_log_repository.dart';
import '../data/repositories/tag_repository.dart';
import '../data/repositories/trusted_device_repository.dart';
import 'crypto/identity_store.dart';
import 'pipeline/sync_bundle_applier.dart';
import 'pipeline/sync_bundle_packer.dart';
import 'pipeline/sync_progress_tracker.dart';
import 'protocol/merge_resolver.dart';
import 'protocol/sync_bundle.dart';
import 'protocol/sync_digest.dart';
import 'transport/libp2p_sync_transport.dart';
import 'transport/sync_transport.dart';
import 'transport/tcp_sync_transport.dart';

export 'pipeline/sync_progress_tracker.dart' show SyncProgressStats, SyncStage;

/// State of the sync orchestrator.
class SyncOrchestratorState {
  const SyncOrchestratorState({
    this.phase = SyncPhase.idle,
    this.devices = const [],
    this.selectedDevice,
    this.sentCount = 0,
    this.totalCount = 0,
    this.receivedCount = 0,
    this.conflicts = const [],
    this.pendingPairing,
    this.receivedNoteIds = const [],
    this.rejectedNoteIds = const [],
    this.error,
    this.outcome,
    this.progressStats = const SyncProgressStats(),
  });

  final SyncPhase phase;
  final List<SyncDevice> devices;
  final SyncDevice? selectedDevice;
  final int sentCount;
  final int totalCount;
  final int receivedCount;
  final List<SyncConflict> conflicts;
  final PairingRequest? pendingPairing;
  final List<String> receivedNoteIds;
  final List<String> rejectedNoteIds;
  final String? error;

  /// Category of the last failure (rejected / timedOut / connectionLost /
  /// protocol / internal). Null when the last operation did not fail.
  final SyncOutcomeCategory? outcome;

  /// Live transfer throughput, dynamic ETA, and stage details.
  final SyncProgressStats progressStats;

  int get bytesTransferred => progressStats.bytesTransferred;
  int get totalBytes => progressStats.totalBytes;
  double get byteProgress => progressStats.byteProgress;
  String get formattedSpeed => progressStats.formattedSpeed;
  String get formattedEta => progressStats.formattedEta;
  String get formattedBytes => progressStats.formattedBytes;
  String? get currentItemName => progressStats.currentItemName;

  SyncOrchestratorState copyWith({
    SyncPhase? phase,
    List<SyncDevice>? devices,
    SyncDevice? selectedDevice,
    bool clearSelectedDevice = false,
    int? sentCount,
    int? totalCount,
    int? receivedCount,
    List<SyncConflict>? conflicts,
    PairingRequest? pendingPairing,
    bool clearPendingPairing = false,
    List<String>? receivedNoteIds,
    List<String>? rejectedNoteIds,
    String? error,
    bool clearError = false,
    SyncOutcomeCategory? outcome,
    bool clearOutcome = false,
    SyncProgressStats? progressStats,
  }) {
    return SyncOrchestratorState(
      phase: phase ?? this.phase,
      devices: devices ?? this.devices,
      selectedDevice:
          clearSelectedDevice ? null : (selectedDevice ?? this.selectedDevice),
      sentCount: sentCount ?? this.sentCount,
      totalCount: totalCount ?? this.totalCount,
      receivedCount: receivedCount ?? this.receivedCount,
      conflicts: conflicts ?? this.conflicts,
      pendingPairing:
          clearPendingPairing ? null : (pendingPairing ?? this.pendingPairing),
      receivedNoteIds: receivedNoteIds ?? this.receivedNoteIds,
      rejectedNoteIds: rejectedNoteIds ?? this.rejectedNoteIds,
      error: clearError ? null : (error ?? this.error),
      outcome: clearOutcome ? null : (outcome ?? this.outcome),
      progressStats: progressStats ?? this.progressStats,
    );
  }
}

/// The phase of a sync operation.
enum SyncPhase {
  idle,
  discovering,
  connecting,
  sending,
  receiving,
  resolving,
  complete,
  error,
}

/// A conflict that requires user resolution.
class SyncConflict {
  const SyncConflict({
    required this.incoming,
    required this.localDeviceName,
    required this.remoteDeviceName,
  });

  final SyncNoteEntry incoming;
  final String localDeviceName;
  final String remoteDeviceName;
}

/// Orchestrates the full sync flow: transport + protocol + resolver + DB.
class SyncOrchestrator extends Notifier<SyncOrchestratorState> {
  @override
  SyncOrchestratorState build() => const SyncOrchestratorState();

  SyncTransport? _transport;
  StreamSubscription? _deviceSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _bytesSub;
  StreamSubscription? _progressSub;
  StreamSubscription? _pairingSub;
  StreamSubscription? _wifiDirectServiceSub;
  StreamSubscription? _wifiDirectGroupSub;
  StreamSubscription? _wifiDirectErrorSub;
  String _localDeviceId = '';
  String _localDeviceName = '';
  bool _stopped = false;
  Completer<void>? _cancelCompleter;
  final SyncProgressTracker _progressTracker = SyncProgressTracker();
  int _lastBundleSizeBytes = 0;

  /// Whether a transport has been initialized (test hook).
  bool get isTransportInitialized => _transport?.isInitialized ?? false;

  /// This device's own dialable multiaddrs (peer id suffixed), e.g.
  /// `/ip4/192.168.1.20/udp/52341/udx/p2p/12D3KooW...`. Populated once the
  /// transport initializes; shown on the receive screen so a sender can add
  /// this device manually when mDNS discovery is unavailable.
  List<String> get localMultiaddresses =>
      _transport?.localMultiaddresses ?? const [];

  /// Connects to a device entered manually as a full multiaddr (must include
  /// the `/p2p/<peer id>` suffix), bypassing mDNS discovery entirely.
  Future<void> connectToManualAddress(
    String address, {
    String? pairingCode,
  }) async {
    final device = SyncDevice.fromManualAddress(address);
    if (device == null) {
      nookLog(
        NookLogKey.sync,
        'Manual connect rejected: invalid address "$address"',
        LogLevel.warning,
      );
      state = state.copyWith(
        phase: SyncPhase.error,
        error: 'Invalid address — it must end with /p2p/<peer id>',
        outcome: SyncOutcomeCategory.internal,
      );
      return;
    }
    nookLog(
      NookLogKey.sync,
      'Manual connect to ${device.deviceId} via ${device.multiaddresses}',
      LogLevel.info,
    );
    await connectToDevice(device, pairingCode: pairingCode);
  }

  /// Serializes received bundles so two frames delivered back-to-back over a
  /// broadcast stream can never interleave DB writes / acks.
  final Queue<List<int>> _bytesQueue = Queue<List<int>>();
  bool _processingBytes = false;

  /// Initializes the transport and gets local device info.
  ///
  /// The default transport is the libp2p (UDX) transport. Pass
  /// [useTcpFallback] to keep the legacy TCP transport. Pass [testTransport]
  /// in tests to inject a mock, [identityStore] to control the libp2p identity
  /// seed, and [localDeviceName] to give this device a friendly name shown
  /// during sync/conflict resolution. [listenAddress] overrides the libp2p
  /// bind address (tests use loopback). [discoveryNetworkEnabled] disables the
  /// transport's mDNS layer entirely (tests keep discovery hermetic).
  Future<void> initializeTransport({
    SyncTransport? testTransport,
    String? localDeviceName,
    bool useTcpFallback = false,
    IdentityStore? identityStore,
    String? listenAddress,
    bool discoveryNetworkEnabled = true,
  }) async {
    if (testTransport != null) {
      _transport = testTransport;
      _localDeviceId =
          await testTransport.getCurrentDeviceId() ?? const Uuid().v4();
      _localDeviceName = localDeviceName ?? 'Test Device';
    } else {
      final SyncTransport transport;
      if (useTcpFallback) {
        final tcp = TcpSyncTransport(localDeviceName: localDeviceName);
        transport = tcp;
      } else {
        transport = Libp2pSyncTransport(
          localDeviceName: localDeviceName,
          identityStore: identityStore,
          listenAddress: listenAddress ?? '/ip4/0.0.0.0/udp/0/udx',
          discoveryNetworkEnabled: discoveryNetworkEnabled,
        );
      }
      _transport = transport;
      await transport.initialize();
      _localDeviceId =
          await transport.getCurrentDeviceId() ?? const Uuid().v4();
      _localDeviceName = localDeviceName ?? 'Nook';
    }

    // The transport's categorized error states drive the UI's distinct
    // outcome treatments (declined vs. timeout vs. connection lost). Subscribe
    // once for the transport's lifetime.
    _ensureStateSubscription();
    _ensureBytesSubscription();
    nookLog(
      NookLogKey.sync,
      'Sync transport initialized ($_localDeviceName)',
      LogLevel.info,
    );
  }

  void _ensureStateSubscription() {
    if (_stateSub != null) return;
    _stateSub = _transport!.sessionStateStream.listen(_onTransportState);
  }

  void _ensureBytesSubscription() {
    if (_bytesSub != null) return;
    _bytesSub = _transport?.bytesReceivedStream.listen(
      _enqueueReceivedBytes,
      onError: (e) {
        state = state.copyWith(
          phase: SyncPhase.error,
          error: 'Receive error: $e',
          outcome: SyncOutcomeCategory.protocol,
        );
      },
    );
  }

  /// Maps a transport session state into the orchestrator state. Only errors
  /// change the phase; the categorized [SyncOutcomeCategory] is carried through
  /// so the UI can render a distinct treatment per failure mode.
  void _onTransportState(SyncSessionState sessionState) {
    if (sessionState.error != null) {
      // Don't overwrite an error that is already set — a delayed/queued
      // transport error arriving after the orchestrator already entered the
      // error phase would flicker the UI with a different message.
      if (state.phase == SyncPhase.error) return;
      nookLog(
        NookLogKey.sync,
        'Sync error: ${sessionState.error}',
        LogLevel.error,
      );
      state = state.copyWith(
        phase: SyncPhase.error,
        error: sessionState.error,
        outcome: sessionState.outcome ?? SyncOutcomeCategory.internal,
      );
    }
  }

  /// Starts discovery for nearby devices (sender mode).
  Future<void> startDiscovery() async {
    if (_transport == null) await initializeTransport();

    _stopped = false;
    nookLog(NookLogKey.sync, 'Sync discovery started', LogLevel.info);
    state = state.copyWith(
      phase: SyncPhase.discovering,
      clearError: true,
      clearOutcome: true,
    );

    _ensureStateSubscription();

    unawaited(_deviceSub?.cancel());
    _deviceSub = _transport!.deviceFoundStream.listen((device) {
      nookLog(
        NookLogKey.sync,
        'Peer discovered: ${device.deviceName}',
        LogLevel.debug,
      );
      final existing = state.devices;
      final match = existing.indexWhere((d) => d.deviceId == device.deviceId);
      if (match == -1) {
        state = state.copyWith(devices: [...existing, device]);
      } else if (device.isOnline != existing[match].isOnline ||
          device.deviceName.isNotEmpty &&
              device.deviceName != existing[match].deviceName) {
        final updated = List<SyncDevice>.from(existing)..[match] = device;
        state = state.copyWith(devices: updated);
      }
    });

    unawaited(_progressSub?.cancel());
    _progressSub = _transport!.progressStream.listen((progress) {
      if (state.phase == SyncPhase.sending) {
        final totalEst = _lastBundleSizeBytes > 0
            ? _lastBundleSizeBytes
            : (state.totalCount > 0 ? state.totalCount * 1024 : 1024);
        final currentBytes = (progress * totalEst).round();
        _progressTracker.updateBytes(currentBytes);
        state = state.copyWith(
          sentCount: (progress * state.totalCount).round(),
          progressStats: _progressTracker.stats,
        );
      }
    });

    await _transport!.startDiscovery();
    await _startWifiDirectDiscovery();
  }

  /// Starts Wi-Fi Direct DNS-SD discovery alongside mDNS. Finds Nook
  /// receivers that are NOT on the same Wi-Fi network (the Quick Share
  /// mechanism, on the existing transport). Best-effort: mDNS still runs.
  Future<void> _startWifiDirectDiscovery() async {
    if (!Platform.isAndroid || !WifiDirect.isSupportedPlatform) return;
    if (!await _ensureWifiDirectPermissions()) return;

    unawaited(_wifiDirectServiceSub?.cancel());
    _wifiDirectServiceSub =
        WifiDirect.serviceStream.listen(_onWifiDirectService);

    unawaited(_wifiDirectErrorSub?.cancel());
    _wifiDirectErrorSub = WifiDirect.errorStream.listen((message) {
      nookLog(NookLogKey.sync, 'Wi-Fi Direct: $message', LogLevel.warning);
    });

    await WifiDirect.discoverServices();
    nookLog(
      NookLogKey.sync,
      'Wi-Fi Direct discovery started',
      LogLevel.info,
    );
  }

  void _onWifiDirectService(WifiDirectService service) {
    final device = SyncDevice.fromWifiDirectService(
      instanceName: service.instanceName,
      deviceAddress: service.deviceAddress,
      txt: service.txt,
    );
    if (device == null) {
      // A non-Nook Wi-Fi Direct service — ignore.
      return;
    }
    if (device.deviceId == _localDeviceId) return;

    nookLog(
      NookLogKey.sync,
      'Wi-Fi Direct device found: "${device.deviceName}" '
      '(${device.deviceId} @ ${device.multiaddresses?.first})',
      LogLevel.info,
    );
    final existing = state.devices;
    final match = existing.indexWhere((d) =>
        d.deviceId == device.deviceId &&
        d.transportType == device.transportType);
    if (match == -1) {
      state = state.copyWith(devices: [...existing, device]);
    }
  }

  Future<bool> _ensureWifiDirectPermissions() async {
    final granted = await NearbyPermissions.check();
    if (granted) return true;
    nookLog(
      NookLogKey.sync,
      'Requesting nearby permissions for Wi-Fi Direct',
      LogLevel.info,
    );
    return NearbyPermissions.request();
  }

  /// Starts advertising for incoming connections (receiver mode).
  Future<void> startAdvertising() async {
    if (_transport == null) await initializeTransport();

    _stopped = false;
    nookLog(NookLogKey.sync, 'Sync advertising started (receiver mode)',
        LogLevel.info);
    state = state.copyWith(
      phase: SyncPhase.receiving,
      clearError: true,
      clearOutcome: true,
    );
    await _transport!.startAdvertising();
    await _startWifiDirectAdvertising();

    _ensureStateSubscription();
    _ensureBytesSubscription();

    // Surface incoming pairing requests so the receive UI can confirm them,
    // or auto-approve if the device is already in the trusted devices store.
    unawaited(_pairingSub?.cancel());
    _pairingSub = _transport!.pairingRequestStream.listen((request) async {
      final db = ref.read(databaseProvider);
      final trustedRepo = TrustedDeviceRepository(db);
      final isTrusted =
          await trustedRepo.isDeviceTrusted(request.remoteDeviceId);

      if (isTrusted) {
        nookLog(
          NookLogKey.sync,
          'Auto-approving pairing from trusted peer: ${request.remoteDeviceName} '
          '(${request.remoteDeviceId})',
          LogLevel.info,
        );
        await _transport?.respondToPairing(request, true);
        state = state.copyWith(
          clearPendingPairing: true,
          phase: SyncPhase.idle,
          selectedDevice: SyncDevice(
            deviceId: request.remoteDeviceId,
            deviceName: request.remoteDeviceName,
            isOnline: true,
          ),
          clearError: true,
        );
        return;
      }

      state = state.copyWith(
        pendingPairing: request,
        phase: SyncPhase.receiving,
        clearError: true,
      );
    });
  }

  /// Creates a Wi-Fi Direct group and registers Nook's DNS-SD service on it,
  /// so receivers are discoverable (and dialable) by senders on a different
  /// Wi-Fi network. Best-effort: mDNS advertising still runs.
  Future<void> _startWifiDirectAdvertising() async {
    if (!Platform.isAndroid || !WifiDirect.isSupportedPlatform) return;
    if (!await _ensureWifiDirectPermissions()) return;

    unawaited(_wifiDirectErrorSub?.cancel());
    _wifiDirectErrorSub = WifiDirect.errorStream.listen((message) {
      nookLog(NookLogKey.sync, 'Wi-Fi Direct: $message', LogLevel.warning);
    });

    final group = await WifiDirect.createGroup();
    if (group == null) {
      nookLog(
        NookLogKey.sync,
        'Wi-Fi Direct group creation failed; mDNS-only',
        LogLevel.warning,
      );
      return;
    }
    nookLog(
      NookLogKey.sync,
      'Wi-Fi Direct group ready (${group.networkName}, owner ${group.ownerAddress})',
      LogLevel.info,
    );

    await _registerWifiDirectService(ownerAddress: group.ownerAddress);

    // Re-register once the framework reports the real group-owner address
    // (some devices only expose it after the group is fully formed).
    unawaited(_wifiDirectGroupSub?.cancel());
    _wifiDirectGroupSub = WifiDirect.groupStream.listen((g) {
      if (g.ownerAddress.isNotEmpty) {
        nookLog(
          NookLogKey.sync,
          'Wi-Fi Direct owner address resolved: ${g.ownerAddress}',
          LogLevel.debug,
        );
        unawaited(_registerWifiDirectService(ownerAddress: g.ownerAddress));
      }
    });
  }

  /// Registers (or replaces) Nook's `_syncnotenet._tcp` service on the active
  /// Wi-Fi Direct group with this device's dialable multiaddr in `dnsaddr`.
  Future<void> _registerWifiDirectService(
      {required String ownerAddress}) async {
    // The UDX host binds 0.0.0.0 with the same port on every interface, so the
    // P2P link dials the owner address + the advertised UDX port.
    String? udxPort;
    for (final addr in localMultiaddresses) {
      final portMatch = RegExp(r'/udp/(\d+)/udx').firstMatch(addr);
      if (portMatch != null) {
        udxPort = portMatch.group(1);
        break;
      }
    }
    if (udxPort == null) {
      nookLog(
        NookLogKey.sync,
        'Wi-Fi Direct: no UDX port available yet, skipping service',
        LogLevel.warning,
      );
      return;
    }
    final resolvedOwner =
        ownerAddress.isNotEmpty ? ownerAddress : _defaultP2pOwnerAddress;
    final dnsaddr = WifiDirect.buildDnsaddr(
      ownerAddress: resolvedOwner,
      udxPort: udxPort,
      peerId: _localDeviceId,
    );
    final instanceName = 'nook-$_localDeviceName';

    final ok = await WifiDirect.registerService(
      instanceName: instanceName,
      txt: {
        'dnsaddr': dnsaddr,
        'name': _localDeviceName,
      },
    );
    nookLog(
      NookLogKey.sync,
      ok
          ? 'Wi-Fi Direct service registered ($instanceName → $dnsaddr)'
          : 'Wi-Fi Direct service registration failed',
      ok ? LogLevel.info : LogLevel.error,
    );
  }

  /// Android's standard Wi-Fi Direct group-owner subnet address.
  static const String _defaultP2pOwnerAddress = '192.168.49.1';

  /// Confirms a pending incoming pairing request, optionally persisting the peer
  /// in the trusted devices repository to enable future automatic pairing.
  Future<void> confirmPairing({bool trustDevice = true}) async {
    final request = state.pendingPairing;
    if (request == null) return;
    await _transport?.respondToPairing(request, true);

    if (trustDevice) {
      final db = ref.read(databaseProvider);
      final trustedRepo = TrustedDeviceRepository(db);
      await trustedRepo.addOrUpdateTrustedDevice(
        peerId: request.remoteDeviceId,
        deviceName: request.remoteDeviceName,
      );
    }

    state = state.copyWith(
      clearPendingPairing: true,
      // The pairing was approved: remember who dialed us so this device can
      // send notes back (ShareIt-style — mobile scans the PC's QR and dials
      // it, then the PC pushes the selected notes to the mobile).
      selectedDevice: SyncDevice(
        deviceId: request.remoteDeviceId,
        deviceName: request.remoteDeviceName,
        isOnline: true,
      ),
    );
  }

  /// Rejects a pending incoming pairing request.
  Future<void> rejectPairing() async {
    final request = state.pendingPairing;
    if (request == null) return;
    await _transport?.respondToPairing(request, false);
    state = state.copyWith(clearPendingPairing: true);
  }

  /// Builds a lightweight [SyncDigest] of all local notes for two-way delta sync.
  Future<SyncDigest> buildLocalDigest() async {
    final db = ref.read(databaseProvider);
    final allNotes = await db.select(db.notes).get();
    final entries = allNotes.map((note) {
      final rawContent =
          '${note.title}:${note.plainText ?? ''}:${note.deltaContent ?? ''}';
      final hash = sha256.convert(utf8.encode(rawContent)).toString();
      return NoteDigestEntry(
        noteId: note.id,
        updatedAt: note.updatedAt.toUtc(),
        syncVersion: note.syncVersion,
        deleted: note.deleted,
        contentHash: hash,
      );
    }).toList();

    return SyncDigest(
      deviceId: _localDeviceId,
      entries: entries,
    );
  }

  /// Computes the reconciliation plan (notes to push, notes to pull, identical notes, conflicts)
  /// given a remote digest.
  SyncReconciliation reconcile(
    SyncDigest remoteDigest, {
    required SyncDigest localDigest,
  }) {
    return SyncReconciliation.reconcile(
      local: localDigest,
      remote: remoteDigest,
    );
  }

  /// Sets or clears the active target device for synchronization.
  void selectDevice(SyncDevice? device) {
    state = state.copyWith(
      selectedDevice: device,
      clearSelectedDevice: device == null,
    );
  }

  /// Connects to a specific device and prepares for transfer.
  Future<void> connectToDevice(SyncDevice device, {String? pairingCode}) async {
    _ensureStateSubscription();

    nookLog(
      NookLogKey.sync,
      'Connecting to ${device.deviceName}',
      LogLevel.info,
    );

    state = state.copyWith(
      phase: SyncPhase.connecting,
      selectedDevice: device,
      clearError: true,
      clearOutcome: true,
    );

    final connected =
        await _transport!.connectToDevice(device, pairingCode: pairingCode);
    if (!connected) {
      // The transport emits a categorized error on its session state stream;
      // only fall back to a generic message when it did not.
      if (state.phase != SyncPhase.error) {
        nookLog(
          NookLogKey.sync,
          'Failed to connect to ${device.deviceName}',
          LogLevel.error,
        );
        state = state.copyWith(
          phase: SyncPhase.error,
          error: 'Failed to connect to ${device.deviceName}',
          outcome: SyncOutcomeCategory.connectionLost,
        );
      }
      return;
    }

    nookLog(
      NookLogKey.sync,
      'Connection established with ${device.deviceName}',
      LogLevel.info,
    );
    state = state.copyWith(phase: SyncPhase.idle);
  }

  /// Whether a transfer is in progress and can be cancelled.
  bool get canCancel =>
      _cancelCompleter != null && !_cancelCompleter!.isCompleted;

  /// Cancels the in-progress transfer by closing the underlying transport stream.
  void cancelTransfer() {
    if (!canCancel) return;
    _cancelCompleter?.complete();
    _transport?.disconnect();
    state = state.copyWith(
      phase: SyncPhase.error,
      error: 'Transfer cancelled',
      outcome: SyncOutcomeCategory.cancelled,
    );
    nookLog(NookLogKey.sync, 'Transfer cancelled by user', LogLevel.info);
  }

  /// Sends selected notes to the connected device.
  Future<void> sendNotes(List<String> noteIds) async {
    if (_transport == null || state.selectedDevice == null) {
      state = state.copyWith(error: 'No device connected');
      return;
    }

    nookLog(
      NookLogKey.sync,
      'Sync started: ${noteIds.length} notes to ${state.selectedDevice!.deviceName}',
      LogLevel.info,
    );

    _progressTracker.start(totalItems: noteIds.length, totalBytes: 0);
    _progressTracker.setStage(
      SyncStage.packaging,
      description: 'Packing notes...',
    );

    state = state.copyWith(
      phase: SyncPhase.sending,
      sentCount: 0,
      totalCount: noteIds.length,
      progressStats: _progressTracker.stats,
    );
    _cancelCompleter = Completer<void>();

    try {
      final db = ref.read(databaseProvider);
      final noteRepo = NoteRepository(db);
      final tagRepo = TagRepository(db);
      final attachmentRepo = AttachmentRepository(db);
      final notebookRepo = NotebookRepository(db);

      final packer = SyncBundlePacker(
        db: db,
        noteRepo: noteRepo,
        attachmentRepo: attachmentRepo,
        tagRepo: tagRepo,
        notebookRepo: notebookRepo,
      );

      final bundle = await packer.pack(
        noteIds: noteIds,
        senderDeviceId: _localDeviceId,
        senderDeviceName: _localDeviceName,
        onProgress: (packedCount, totalCount, currentTitle) {
          _progressTracker.updateItem(
            itemName: currentTitle,
            itemIndex: packedCount,
          );
          state = state.copyWith(
            sentCount: packedCount,
            progressStats: _progressTracker.stats,
          );
        },
      );

      if (_cancelCompleter?.isCompleted == true) {
        state = state.copyWith(
          phase: SyncPhase.error,
          error: 'Transfer cancelled',
          outcome: SyncOutcomeCategory.cancelled,
        );
        return;
      }

      if (bundle.notes.isEmpty) {
        nookLog(NookLogKey.sync, 'Send aborted: no valid notes to send',
            LogLevel.warning);
        state = state.copyWith(
          phase: SyncPhase.error,
          error: 'No valid notes to send',
        );
        return;
      }

      // Serialize to CBOR
      final bundleBytes = bundle.toCbor();
      _lastBundleSizeBytes = bundleBytes.length;
      _progressTracker.start(
        totalItems: bundle.notes.length,
        totalBytes: bundleBytes.length,
      );
      _progressTracker.setStage(
        SyncStage.transferring,
        description: 'Streaming notes...',
      );

      nookLog(
        NookLogKey.sync,
        'Bundle built: ${bundle.notes.length} note(s), ${bundleBytes.length} bytes',
        LogLevel.info,
      );

      // Send via transport and capture the receiver's ack.
      final ack = await _transport!.sendData(bundleBytes);

      if (ack == null) {
        // The transport emits a categorized error; fall back only if it did not.
        if (state.phase != SyncPhase.error) {
          state = state.copyWith(
            phase: SyncPhase.error,
            error: 'Send failed: no acknowledgment received',
            outcome: SyncOutcomeCategory.timedOut,
          );
        }
        return;
      }

      // Log each sent note
      final syncLog = SyncLogRepository(db);
      for (final entry in bundle.notes) {
        await syncLog.logSent(
          deviceId: _localDeviceId,
          deviceName: _localDeviceName,
          noteId: entry.noteId,
        );
      }

      // Increment syncVersion only for notes the receiver actually kept.
      final accepted = ack.receivedNoteIds;
      for (final noteId in accepted) {
        await noteRepo.bumpSyncVersion(noteId);
      }
      if (accepted.isNotEmpty) {
        nookLog(
          NookLogKey.sync,
          'syncVersion bumped for ${accepted.length} accepted note(s)',
          LogLevel.debug,
        );
      }
      if (ack.rejectedNoteIds.isNotEmpty) {
        nookLog(
          NookLogKey.sync,
          'Receiver rejected ${ack.rejectedNoteIds.length} note(s)',
          LogLevel.warning,
        );
      }

      _progressTracker.complete();
      state = state.copyWith(
        phase: SyncPhase.complete,
        sentCount: bundle.notes.length,
        receivedNoteIds: ack.receivedNoteIds,
        rejectedNoteIds: ack.rejectedNoteIds,
        progressStats: _progressTracker.stats,
      );
      nookLog(
        NookLogKey.sync,
        'Sync complete: ${bundle.notes.length} notes sent',
        LogLevel.info,
      );
    } catch (e) {
      nookLog(NookLogKey.sync, 'Send failed: $e', LogLevel.error);
      state = state.copyWith(
        phase: SyncPhase.error,
        error: 'Send failed: $e',
        outcome: SyncOutcomeCategory.internal,
      );
    } finally {
      _cancelCompleter = null;
    }
  }

  /// Queues received bytes and drains the queue serially. Broadcast streams do
  /// not await async listeners, so without this serialization two bundles
  /// arriving back-to-back could interleave DB writes and acks.
  void _enqueueReceivedBytes(List<int> bytes) {
    _bytesQueue.add(bytes);
    if (_processingBytes) return;
    _processingBytes = true;
    unawaited(_drainBytesQueue());
  }

  Future<void> _drainBytesQueue() async {
    try {
      while (_bytesQueue.isNotEmpty && !_stopped) {
        final bytes = _bytesQueue.removeFirst();
        await _handleReceivedBytes(bytes);
      }
    } finally {
      _processingBytes = false;
    }
  }

  /// Handles received CBOR bytes from the transport.
  Future<void> _handleReceivedBytes(List<int> bytes) async {
    if (_stopped) return;
    state = state.copyWith(phase: SyncPhase.receiving);

    try {
      final bundle = SyncBundle.fromCbor(Uint8List.fromList(bytes));
      nookLog(
        NookLogKey.sync,
        'Bundle received from ${bundle.senderDeviceName}: '
        '${bundle.notes.length} notes',
        LogLevel.debug,
      );

      // Reject bundles from an incompatible protocol version rather than
      // silently misparsing them.
      if (bundle.protocolVersion != '1.0') {
        state = state.copyWith(
          phase: SyncPhase.error,
          error:
              'Unsupported sync protocol ${bundle.protocolVersion} (expected 1.0)',
        );
        return;
      }

      final db = ref.read(databaseProvider);
      final noteRepo = NoteRepository(db);
      final tagRepo = TagRepository(db);
      final attachmentRepo = AttachmentRepository(db);
      final syncLog = SyncLogRepository(db);
      final resolver = MergeResolver(noteRepo, NotebookRepository(db));

      state = state.copyWith(phase: SyncPhase.resolving);

      _progressTracker.start(
        totalItems: bundle.notes.length,
        totalBytes: bytes.length,
      );
      _progressTracker.setStage(
        SyncStage.resolvingConflicts,
        description: 'Applying incoming notes...',
      );

      final applier = SyncBundleApplier(
        db: db,
        noteRepo: noteRepo,
        notebookRepo: NotebookRepository(db),
        attachmentRepo: attachmentRepo,
        tagRepo: tagRepo,
        syncLog: syncLog,
        resolver: resolver,
        restoreDirectoryOverride: restoredAttachmentsDirectoryOverride,
      );

      final result = await applier.apply(
        bundle: bundle,
        localDeviceName: _localDeviceName,
        onProgress: (appliedCount, totalCount, currentTitle) {
          _progressTracker.updateItem(
            itemName: currentTitle,
            itemIndex: appliedCount,
          );
          state = state.copyWith(
            receivedCount: appliedCount,
            progressStats: _progressTracker.stats,
          );
        },
      );

      // Send ack back to sender.
      // Conflicts are NOT included in rejectedNoteIds — the user has not
      // decided yet. The sender learns the outcome only when the user resolves
      // each conflict (via a follow-up ack in resolveConflict()).
      final ack = result.ack;
      nookLog(
        NookLogKey.sync,
        'Acking sender: ${result.receivedNoteIds.length} received, '
        '${result.rejectedNoteIds.length} rejected',
        LogLevel.debug,
      );
      await _transport?.sendAck(ack.toCbor());

      if (result.conflicts.isNotEmpty) {
        // Deduplicate: only add conflicts for notes not already in the list.
        final existingConflictIds =
            state.conflicts.map((c) => c.incoming.noteId).toSet();
        final newConflicts = result.conflicts
            .where((c) => !existingConflictIds.contains(c.incoming.noteId))
            .toList();
        state = state.copyWith(
          phase: SyncPhase.resolving,
          conflicts: [...state.conflicts, ...newConflicts],
          receivedCount: result.receivedNoteIds.length,
          receivedNoteIds: result.receivedNoteIds,
          rejectedNoteIds: result.rejectedNoteIds,
          progressStats: _progressTracker.stats,
        );
      } else {
        _progressTracker.complete();
        state = state.copyWith(
          phase: SyncPhase.complete,
          receivedCount: result.receivedNoteIds.length,
          receivedNoteIds: result.receivedNoteIds,
          rejectedNoteIds: result.rejectedNoteIds,
          progressStats: _progressTracker.stats,
        );
        nookLog(
          NookLogKey.sync,
          'Sync receive complete: ${result.receivedNoteIds.length} notes',
          LogLevel.info,
        );
      }
    } catch (e) {
      nookLog(
        NookLogKey.sync,
        'Failed to process received bundle: $e',
        LogLevel.error,
      );
      state = state.copyWith(
        phase: SyncPhase.error,
        error: 'Failed to process received bundle: $e',
        outcome: SyncOutcomeCategory.internal,
      );
    }
  }

  /// Resolves a conflict by applying the user's choice.
  Future<void> resolveConflict(
    SyncConflict conflict,
    String choice, // 'local', 'remote', or 'both'
  ) async {
    // Remove the conflict from state immediately to prevent double-taps from
    // triggering duplicate DB operations (e.g. "keep both" calling insertAsNew
    // twice). The async work below still executes, but the UI removes the
    // card before the DB round-trip completes.
    final remaining = List<SyncConflict>.from(state.conflicts)
      ..remove(conflict);
    state = state.copyWith(
      conflicts: remaining,
      phase: remaining.isEmpty ? SyncPhase.complete : SyncPhase.resolving,
    );

    final db = ref.read(databaseProvider);
    final noteRepo = NoteRepository(db);
    final attachmentRepo = AttachmentRepository(db);
    final syncLog = SyncLogRepository(db);
    final resolver = MergeResolver(noteRepo, NotebookRepository(db));
    final applier = SyncBundleApplier(
      db: db,
      noteRepo: noteRepo,
      attachmentRepo: attachmentRepo,
      restoreDirectoryOverride: restoredAttachmentsDirectoryOverride,
    );

    switch (choice) {
      case 'remote':
        nookLog(
          NookLogKey.sync,
          'Conflict on ${conflict.incoming.noteId}: keeping remote version',
          LogLevel.info,
        );
        // Overwrite local with remote version
        await resolver.forceOverwrite(conflict.incoming);
        await applier.restoreAttachments(entry: conflict.incoming);
        await applier.restoreTags(entry: conflict.incoming);
        await applier.restoreChecklistItems(entry: conflict.incoming);
        await syncLog.logReceived(
          deviceId: conflict.incoming.deviceOriginId,
          deviceName: conflict.remoteDeviceName,
          noteId: conflict.incoming.noteId,
        );
        break;
      case 'local':
        nookLog(
          NookLogKey.sync,
          'Conflict on ${conflict.incoming.noteId}: keeping local version',
          LogLevel.info,
        );
        // Keep local version — do nothing to DB
        await syncLog.logConflict(
          deviceId: conflict.incoming.deviceOriginId,
          deviceName: conflict.remoteDeviceName,
          noteId: conflict.incoming.noteId,
        );
        break;
      case 'both':
        nookLog(
          NookLogKey.sync,
          'Conflict on ${conflict.incoming.noteId}: keeping both versions',
          LogLevel.info,
        );
        // Keep both — insert incoming as new, owned by THIS device so the
        // duplicate never re-conflicts on the next sync.
        await resolver.insertAsNew(
          conflict.incoming,
          originIdOverride: _localDeviceId,
        );
        await applier.restoreAttachments(entry: conflict.incoming);
        await syncLog.logReceived(
          deviceId: _localDeviceId,
          deviceName: conflict.remoteDeviceName,
          noteId: conflict.incoming.noteId,
        );
        break;
    }
  }

  /// Stops the current sync operation and cleans up.
  Future<void> stop() async {
    nookLog(NookLogKey.sync, 'Sync stopped', LogLevel.info);
    _stopped = true;
    _bytesQueue.clear();
    _processingBytes = false;
    unawaited(_deviceSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_bytesSub?.cancel());
    unawaited(_progressSub?.cancel());
    unawaited(_pairingSub?.cancel());
    unawaited(_wifiDirectServiceSub?.cancel());
    unawaited(_wifiDirectGroupSub?.cancel());
    unawaited(_wifiDirectErrorSub?.cancel());
    _deviceSub = null;
    _stateSub = null;
    _bytesSub = null;
    _progressSub = null;
    _pairingSub = null;
    _wifiDirectServiceSub = null;
    _wifiDirectGroupSub = null;
    _wifiDirectErrorSub = null;

    unawaited(WifiDirect.cleanup());

    await _transport?.disconnect();
    state = const SyncOrchestratorState();
  }

  void dispose() {
    _stopped = true;
    _bytesQueue.clear();
    unawaited(_deviceSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_bytesSub?.cancel());
    unawaited(_progressSub?.cancel());
    unawaited(_pairingSub?.cancel());
    unawaited(_wifiDirectServiceSub?.cancel());
    unawaited(_wifiDirectGroupSub?.cancel());
    unawaited(_wifiDirectErrorSub?.cancel());
    _deviceSub = null;
    _stateSub = null;
    _bytesSub = null;
    _progressSub = null;
    _pairingSub = null;
    _wifiDirectServiceSub = null;
    _wifiDirectGroupSub = null;
    _wifiDirectErrorSub = null;
    unawaited(_transport?.disconnect());
    _transport?.dispose();
  }

  /// Where received attachment bytes are re-materialised on disk. Defaults to
  /// the app documents directory; tests override it to avoid path_provider.
  Directory? restoredAttachmentsDirectoryOverride;
}

/// Provider for the sync orchestrator.
final syncOrchestratorProvider =
    NotifierProvider<SyncOrchestrator, SyncOrchestratorState>(
  SyncOrchestrator.new,
);

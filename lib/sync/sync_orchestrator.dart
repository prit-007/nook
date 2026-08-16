import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/platform/nearby_permissions.dart';
import '../core/platform/wifi_direct.dart';
import '../core/providers/database_provider.dart';
import '../core/providers/talker_provider.dart';
import '../data/repositories/attachment_repository.dart';
import '../data/repositories/note_repository.dart';
import '../data/repositories/sync_log_repository.dart';
import 'crypto/identity_store.dart';
import 'media_path_rewriter.dart';
import 'protocol/merge_resolver.dart';
import 'protocol/sync_bundle.dart';
import 'transport/libp2p_sync_transport.dart';
import 'transport/sync_transport.dart';
import 'transport/tcp_sync_transport.dart';

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
      _localDeviceId = const Uuid().v4();
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

  /// Maps a transport session state into the orchestrator state. Only errors
  /// change the phase; the categorized [SyncOutcomeCategory] is carried through
  /// so the UI can render a distinct treatment per failure mode.
  void _onTransportState(SyncSessionState sessionState) {
    if (sessionState.error != null) {
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
        state = state.copyWith(
          sentCount: (progress * state.totalCount).round(),
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

    // Listen for incoming connections
    unawaited(_bytesSub?.cancel());
    _bytesSub = _transport!.bytesReceivedStream.listen(
      _enqueueReceivedBytes,
      onError: (e) {
        state = state.copyWith(
          phase: SyncPhase.error,
          error: 'Receive error: $e',
          outcome: SyncOutcomeCategory.protocol,
        );
      },
    );

    // Surface incoming pairing requests so the receive UI can confirm them.
    unawaited(_pairingSub?.cancel());
    _pairingSub = _transport!.pairingRequestStream.listen((request) {
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

  /// Confirms a pending incoming pairing request.
  Future<void> confirmPairing() async {
    final request = state.pendingPairing;
    if (request == null) return;
    await _transport?.respondToPairing(request, true);
    state = state.copyWith(clearPendingPairing: true);
  }

  /// Rejects a pending incoming pairing request.
  Future<void> rejectPairing() async {
    final request = state.pendingPairing;
    if (request == null) return;
    await _transport?.respondToPairing(request, false);
    state = state.copyWith(clearPendingPairing: true);
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

    state = state.copyWith(
      phase: SyncPhase.sending,
      sentCount: 0,
      totalCount: noteIds.length,
    );

    try {
      final db = ref.read(databaseProvider);
      final noteRepo = NoteRepository(db);
      final attachmentRepo = AttachmentRepository(db);

      // Build SyncNoteEntry for each selected note
      final entries = <SyncNoteEntry>[];
      for (final noteId in noteIds) {
        final note = await noteRepo.getNoteById(noteId);
        if (note == null) continue;

        // Attach all of the note's attachment file bytes (images + doodle layers).
        final attachments = <SyncAttachment>[];
        final attachmentRows = await attachmentRepo.getAllForNote(noteId);
        for (final row in attachmentRows) {
          final file = File(row.filePath);
          if (file.existsSync()) {
            Uint8List? thumbBytes;
            final thumbPath = row.thumbnailPath;
            if (thumbPath != null && thumbPath.isNotEmpty) {
              final thumbFile = File(thumbPath);
              if (thumbFile.existsSync()) {
                thumbBytes = thumbFile.readAsBytesSync();
              }
            }
            attachments.add(SyncAttachment(
              id: row.id,
              type: row.type.name,
              sortOrder: row.sortOrder,
              bytes: file.readAsBytesSync(),
              filePath: row.filePath,
              thumbnailPath: thumbPath,
              thumbnailBytes: thumbBytes,
            ));
          } else {
            nookLog(
              NookLogKey.sync,
              'Attachment ${row.id} missing on disk: ${row.filePath}',
              LogLevel.warning,
            );
          }
        }

        entries.add(SyncNoteEntry(
          noteId: note.id,
          syncVersion: note.syncVersion,
          updatedAt: note.updatedAt,
          deviceOriginId: note.deviceOriginId,
          noteFields: {
            'title': note.title,
            'type': note.type.name,
            'colorSeed': note.colorSeed,
            'pinned': note.pinned,
            'locked': note.locked,
            'notebookId': note.notebookId,
            'deltaContent': note.deltaContent,
            'plainText': note.plainText,
          },
          attachments: attachments.isEmpty ? null : attachments,
        ));
        nookLog(
          NookLogKey.sync,
          'Packed note ${note.id} "${note.title}" '
          '(${attachments.length} attachment(s), ${note.deltaContent?.length ?? 0} delta bytes)',
          LogLevel.debug,
        );
      }

      if (entries.isEmpty) {
        nookLog(NookLogKey.sync, 'Send aborted: no valid notes to send',
            LogLevel.warning);
        state = state.copyWith(
          phase: SyncPhase.error,
          error: 'No valid notes to send',
        );
        return;
      }

      // Build the bundle
      final bundle = SyncBundle(
        protocolVersion: '1.0',
        senderDeviceId: _localDeviceId,
        senderDeviceName: _localDeviceName,
        sentAt: DateTime.now(),
        notes: entries,
      );

      // Serialize to CBOR
      final bundleBytes = bundle.toCbor();
      nookLog(
        NookLogKey.sync,
        'Bundle built: ${entries.length} note(s), ${bundleBytes.length} bytes',
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
      for (final entry in entries) {
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

      state = state.copyWith(
        phase: SyncPhase.complete,
        sentCount: entries.length,
        receivedNoteIds: ack.receivedNoteIds,
        rejectedNoteIds: ack.rejectedNoteIds,
      );
      nookLog(
        NookLogKey.sync,
        'Sync complete: ${entries.length} notes sent',
        LogLevel.info,
      );
    } catch (e) {
      nookLog(NookLogKey.sync, 'Send failed: $e', LogLevel.error);
      state = state.copyWith(
        phase: SyncPhase.error,
        error: 'Send failed: $e',
      );
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
      final attachmentRepo = AttachmentRepository(db);
      final syncLog = SyncLogRepository(db);
      final resolver = MergeResolver(noteRepo);

      state = state.copyWith(phase: SyncPhase.resolving);

      final receivedIds = <String>[];
      final rejectedIds = <String>[];
      final conflicts = <SyncConflict>[];

      for (final entry in bundle.notes) {
        final action = await resolver.resolveIncoming(entry);

        switch (action) {
          case MergeAction.insertAsNew:
          case MergeAction.overwrite:
            nookLog(
              NookLogKey.sync,
              'Incoming note ${entry.noteId} — '
              '${action == MergeAction.insertAsNew ? 'inserting' : 'overwriting'}',
              LogLevel.info,
            );
            await resolver.applyIncoming(entry);
            await _restoreAttachments(
                entry: entry, attachmentRepo: attachmentRepo);
            receivedIds.add(entry.noteId);
            await syncLog.logReceived(
              deviceId: bundle.senderDeviceId,
              deviceName: bundle.senderDeviceName,
              noteId: entry.noteId,
            );
            break;

          case MergeAction.promptUser:
            // Pause and surface conflict for user resolution
            nookLog(
              NookLogKey.sync,
              'Conflict detected: ${entry.noteId}',
              LogLevel.warning,
            );
            conflicts.add(SyncConflict(
              incoming: entry,
              localDeviceName: _localDeviceName,
              remoteDeviceName: bundle.senderDeviceName,
            ));
            break;

          case MergeAction.ignore:
            nookLog(
              NookLogKey.sync,
              'Incoming note ${entry.noteId} ignored (older or deleted)',
              LogLevel.info,
            );
            rejectedIds.add(entry.noteId);
            break;
        }

        state = state.copyWith(
          receivedCount: receivedIds.length,
        );
      }

      // Send ack back to sender.
      final ack = SyncAck(
        receivedNoteIds: receivedIds,
        rejectedNoteIds: rejectedIds,
      );
      nookLog(
        NookLogKey.sync,
        'Acking sender: ${receivedIds.length} received, '
        '${rejectedIds.length} rejected',
        LogLevel.debug,
      );
      await _transport?.sendAck(ack.toCbor());

      if (conflicts.isNotEmpty) {
        state = state.copyWith(
          phase: SyncPhase.resolving,
          conflicts: [...state.conflicts, ...conflicts],
        );
      } else {
        state = state.copyWith(phase: SyncPhase.complete);
        nookLog(
          NookLogKey.sync,
          'Sync receive complete: ${receivedIds.length} notes',
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
      );
    }
  }

  /// Resolves a conflict by applying the user's choice.
  Future<void> resolveConflict(
    SyncConflict conflict,
    String choice, // 'local', 'remote', or 'both'
  ) async {
    final db = ref.read(databaseProvider);
    final noteRepo = NoteRepository(db);
    final attachmentRepo = AttachmentRepository(db);
    final syncLog = SyncLogRepository(db);
    final resolver = MergeResolver(noteRepo);

    switch (choice) {
      case 'remote':
        nookLog(
          NookLogKey.sync,
          'Conflict on ${conflict.incoming.noteId}: keeping remote version',
          LogLevel.info,
        );
        // Overwrite local with remote version
        await resolver.forceOverwrite(conflict.incoming);
        await _restoreAttachments(
            entry: conflict.incoming, attachmentRepo: attachmentRepo);
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
        await _restoreAttachments(
            entry: conflict.incoming, attachmentRepo: attachmentRepo);
        await syncLog.logReceived(
          deviceId: _localDeviceId,
          deviceName: conflict.remoteDeviceName,
          noteId: conflict.incoming.noteId,
        );
        break;
    }

    final remaining = List<SyncConflict>.from(state.conflicts)
      ..remove(conflict);
    state = state.copyWith(
      conflicts: remaining,
      phase: remaining.isEmpty ? SyncPhase.complete : SyncPhase.resolving,
    );
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
    unawaited(_deviceSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_bytesSub?.cancel());
    unawaited(_progressSub?.cancel());
    unawaited(_pairingSub?.cancel());
    unawaited(_wifiDirectServiceSub?.cancel());
    unawaited(_wifiDirectGroupSub?.cancel());
    unawaited(_wifiDirectErrorSub?.cancel());
    _transport?.dispose();
  }

  /// Where received attachment bytes are re-materialised on disk. Defaults to
  /// the app documents directory; tests override it to avoid path_provider.
  Directory? restoredAttachmentsDirectoryOverride;

  /// Restores all attachment bytes into the app's managed documents directory
  /// and creates Attachment rows (images + doodle layers) preserving ids/order.
  ///
  /// Existing attachment rows for the note are replaced (not duplicated) so a
  /// re-sync of the same note cannot accumulate orphaned rows or files.
  ///
  /// Doodles are restored in the canonical layout `DoodleStorage` expects
  /// (`<docs>/<id>.doodle.json` + `<docs>/<id>_thumb.png`) so strokes stay
  /// editable after sync, and the note's delta is re-pointed at the restored
  /// paths — the sender's absolute paths (e.g. a Windows `C:\Users\...`) do not
  /// exist on this device and must not be left in the document.
  Future<void> _restoreAttachments({
    required SyncNoteEntry entry,
    required AttachmentRepository attachmentRepo,
  }) async {
    final attachments = entry.attachments;
    if (attachments == null || attachments.isEmpty) return;

    final noteRepo = NoteRepository(ref.read(databaseProvider));
    final note = await noteRepo.getNoteById(entry.noteId);
    if (note == null) return;

    final baseDir = restoredAttachmentsDirectoryOverride ??
        await getApplicationDocumentsDirectory();
    final noteDir = Directory('${baseDir.path}/sync/attachments');
    await noteDir.create(recursive: true);

    // Delete existing attachments first so overwrites never duplicate.
    await attachmentRepo.deleteAllForNote(note.id);
    nookLog(
      NookLogKey.sync,
      'Restoring ${attachments.length} attachment(s) for ${entry.noteId} '
      'into ${baseDir.path}',
      LogLevel.info,
    );

    final restored = <RestoredMedia>[];
    for (var i = 0; i < attachments.length; i++) {
      final att = attachments[i];
      final restoredId =
          await _resolveSyncedAttachmentId(att.id, attachmentRepo);

      final isDoodle = att.type == 'doodleLayer';
      if (isDoodle && att.id.isNotEmpty) {
        // Canonical DoodleStorage layout: sidecar + thumbnail at the documents
        // root so the doodle stays editable (and its thumbnail renders).
        await File('${baseDir.path}/$restoredId.doodle.json')
            .writeAsBytes(att.bytes, flush: true);
        if (att.thumbnailBytes != null && att.thumbnailBytes!.isNotEmpty) {
          await File('${baseDir.path}/${restoredId}_thumb.png')
              .writeAsBytes(att.thumbnailBytes!, flush: true);
        }
        await attachmentRepo.addDoodle(
          noteId: note.id,
          filePath: '${baseDir.path}/$restoredId.doodle.json',
          id: restoredId,
          sortOrder: att.sortOrder,
        );
        if (att.thumbnailBytes != null && att.thumbnailBytes!.isNotEmpty) {
          await attachmentRepo.updateThumbnail(
              restoredId, '${baseDir.path}/${restoredId}_thumb.png');
        }
        restored.add(RestoredMedia(
          attachmentId: att.id,
          newAttachmentId: restoredId != att.id ? restoredId : null,
          originalFilePath: att.filePath,
          originalThumbnailPath: att.thumbnailPath,
          newFilePath: '${baseDir.path}/$restoredId.doodle.json',
          newThumbnailPath: '${baseDir.path}/${restoredId}_thumb.png',
        ));
        nookLog(
          NookLogKey.sync,
          'Restored doodle $restoredId sidecar -> '
          '${baseDir.path}/$restoredId.doodle.json',
          LogLevel.debug,
        );
        continue;
      }

      // Image, or a legacy doodle without an id. Keep the existing
      // `<noteId>_<idPart>` layout under sync/attachments.
      final ext = att.type == 'doodleLayer' ? 'drawn' : 'img';
      final idPart = att.id.isEmpty ? '${att.sortOrder}_$i' : att.id;
      final fileName = '${entry.noteId}_$idPart.$ext';
      final filePath = '${noteDir.path}/$fileName';
      await File(filePath).writeAsBytes(att.bytes, flush: true);

      String? thumbPath;
      if (att.thumbnailBytes != null && att.thumbnailBytes!.isNotEmpty) {
        thumbPath = '${noteDir.path}/${entry.noteId}_$idPart.thumb.$ext';
        await File(thumbPath).writeAsBytes(att.thumbnailBytes!, flush: true);
      }

      if (att.type == 'doodleLayer') {
        await attachmentRepo.addDoodle(
          noteId: note.id,
          filePath: filePath,
          id: restoredId,
          sortOrder: att.sortOrder,
        );
      } else {
        await attachmentRepo.addImage(
          noteId: note.id,
          filePath: filePath,
          id: restoredId,
          thumbnailPath: thumbPath,
          sortOrder: att.sortOrder,
        );
      }
      restored.add(RestoredMedia(
        attachmentId: att.id,
        newAttachmentId: restoredId != att.id ? restoredId : null,
        originalFilePath: att.filePath,
        originalThumbnailPath: att.thumbnailPath,
        newFilePath: filePath,
        newThumbnailPath: thumbPath,
      ));
      nookLog(
        NookLogKey.sync,
        'Restored attachment $restoredId (${att.type}) -> $filePath',
        LogLevel.debug,
      );
    }

    // Re-point the note's delta at the restored files so media renders (and
    // doodles stay editable) on this device instead of referencing the
    // sender's absolute paths.
    final originalDelta = note.deltaContent ?? '';
    final rewrittenDelta = rewriteMediaPaths(originalDelta, restored);
    if (rewrittenDelta != originalDelta) {
      await noteRepo.updateContent(
        note.id,
        deltaContent: rewrittenDelta,
        plainText: note.plainText,
        updatedAt: note.updatedAt,
      );
      nookLog(
        NookLogKey.sync,
        'Delta re-pointed for ${entry.noteId} '
        '(${restored.length} media reference(s) rewritten)',
        LogLevel.info,
      );
    } else {
      nookLog(
        NookLogKey.sync,
        'Delta for ${entry.noteId} unchanged (no media paths to rewrite)',
        LogLevel.debug,
      );
    }
  }

  /// Returns an attachment id that is free on this device. A sender-chosen id
  /// that already belongs to a different local attachment is remapped to a
  /// fresh UUID (and the delta's reference is updated accordingly).
  Future<String> _resolveSyncedAttachmentId(
    String incomingId,
    AttachmentRepository attachmentRepo,
  ) async {
    if (incomingId.isEmpty) return const Uuid().v4();
    final existing = await attachmentRepo.getById(incomingId);
    if (existing == null) return incomingId;
    nookLog(
      NookLogKey.sync,
      'Attachment id collision $incomingId; remapping to fresh id',
      LogLevel.warning,
    );
    return const Uuid().v4();
  }
}

/// Provider for the sync orchestrator.
final syncOrchestratorProvider =
    NotifierProvider<SyncOrchestrator, SyncOrchestratorState>(
  SyncOrchestrator.new,
);

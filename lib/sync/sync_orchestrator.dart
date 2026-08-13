import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/providers/database_provider.dart';
import '../data/repositories/attachment_repository.dart';
import '../data/repositories/note_repository.dart';
import '../data/repositories/sync_log_repository.dart';
import 'crypto/identity_store.dart';
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
  String _localDeviceId = '';
  String _localDeviceName = '';
  bool _stopped = false;

  /// Whether a transport has been initialized (test hook).
  bool get isTransportInitialized => _transport?.isInitialized ?? false;

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
  /// bind address (tests use loopback).
  Future<void> initializeTransport({
    SyncTransport? testTransport,
    String? localDeviceName,
    bool useTcpFallback = false,
    IdentityStore? identityStore,
    String? listenAddress,
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
    state = state.copyWith(
      phase: SyncPhase.discovering,
      clearError: true,
      clearOutcome: true,
    );

    _ensureStateSubscription();

    unawaited(_deviceSub?.cancel());
    _deviceSub = _transport!.deviceFoundStream.listen((device) {
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
  }

  /// Starts advertising for incoming connections (receiver mode).
  Future<void> startAdvertising() async {
    if (_transport == null) await initializeTransport();

    _stopped = false;
    state = state.copyWith(
      phase: SyncPhase.receiving,
      clearError: true,
      clearOutcome: true,
    );
    await _transport!.startAdvertising();

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
        state = state.copyWith(
          phase: SyncPhase.error,
          error: 'Failed to connect to ${device.deviceName}',
          outcome: SyncOutcomeCategory.connectionLost,
        );
      }
      return;
    }

    state = state.copyWith(phase: SyncPhase.idle);
  }

  /// Sends selected notes to the connected device.
  Future<void> sendNotes(List<String> noteIds) async {
    if (_transport == null || state.selectedDevice == null) {
      state = state.copyWith(error: 'No device connected');
      return;
    }

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
            attachments.add(SyncAttachment(
              id: row.id,
              type: row.type.name,
              sortOrder: row.sortOrder,
              bytes: file.readAsBytesSync(),
            ));
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
      }

      if (entries.isEmpty) {
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

      state = state.copyWith(
        phase: SyncPhase.complete,
        sentCount: entries.length,
        receivedNoteIds: ack.receivedNoteIds,
        rejectedNoteIds: ack.rejectedNoteIds,
      );
    } catch (e) {
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
            conflicts.add(SyncConflict(
              incoming: entry,
              localDeviceName: _localDeviceName,
              remoteDeviceName: bundle.senderDeviceName,
            ));
            break;

          case MergeAction.ignore:
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
      await _transport?.sendAck(ack.toCbor());

      if (conflicts.isNotEmpty) {
        state = state.copyWith(
          phase: SyncPhase.resolving,
          conflicts: [...state.conflicts, ...conflicts],
        );
      } else {
        state = state.copyWith(phase: SyncPhase.complete);
      }
    } catch (e) {
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
        // Keep local version — do nothing to DB
        await syncLog.logConflict(
          deviceId: conflict.incoming.deviceOriginId,
          deviceName: conflict.remoteDeviceName,
          noteId: conflict.incoming.noteId,
        );
        break;
      case 'both':
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
    _stopped = true;
    _bytesQueue.clear();
    _processingBytes = false;
    unawaited(_deviceSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_bytesSub?.cancel());
    unawaited(_progressSub?.cancel());
    unawaited(_pairingSub?.cancel());
    _deviceSub = null;
    _stateSub = null;
    _bytesSub = null;
    _progressSub = null;
    _pairingSub = null;

    await _transport?.disconnect();
    state = const SyncOrchestratorState();
  }

  void dispose() {
    unawaited(_deviceSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_bytesSub?.cancel());
    unawaited(_progressSub?.cancel());
    unawaited(_pairingSub?.cancel());
    _transport?.dispose();
  }

  /// Restores all attachment bytes into the app's managed documents directory
  /// and creates Attachment rows (images + doodle layers) preserving ids/order.
  ///
  /// Existing attachment rows for the note are replaced (not duplicated) so a
  /// re-sync of the same note cannot accumulate orphaned rows or files.
  Future<void> _restoreAttachments({
    required SyncNoteEntry entry,
    required AttachmentRepository attachmentRepo,
  }) async {
    final attachments = entry.attachments;
    if (attachments == null || attachments.isEmpty) return;

    final noteRepo = NoteRepository(ref.read(databaseProvider));
    final note = await noteRepo.getNoteById(entry.noteId);
    if (note == null) return;

    final baseDir = await getApplicationDocumentsDirectory();
    final noteDir = Directory('${baseDir.path}/sync/attachments');
    await noteDir.create(recursive: true);

    // Delete existing attachments first so overwrites never duplicate.
    await attachmentRepo.deleteAllForNote(note.id);

    for (var i = 0; i < attachments.length; i++) {
      final att = attachments[i];
      final ext = att.type == 'doodleLayer' ? 'drawn' : 'img';
      // Ensure a unique filename even when ids are empty and sortOrder collides.
      final idPart = att.id.isEmpty ? '${att.sortOrder}_$i' : att.id;
      final fileName = '${entry.noteId}_$idPart.$ext';
      final filePath = '${noteDir.path}/$fileName';
      await File(filePath).writeAsBytes(att.bytes, flush: true);

      if (att.type == 'doodleLayer') {
        await attachmentRepo.addDoodle(
          noteId: note.id,
          filePath: filePath,
          id: att.id.isEmpty ? null : att.id,
          sortOrder: att.sortOrder,
        );
      } else {
        await attachmentRepo.addImage(
          noteId: note.id,
          filePath: filePath,
          id: att.id.isEmpty ? null : att.id,
          sortOrder: att.sortOrder,
        );
      }
    }
  }
}

/// Provider for the sync orchestrator.
final syncOrchestratorProvider =
    NotifierProvider<SyncOrchestrator, SyncOrchestratorState>(
  SyncOrchestrator.new,
);

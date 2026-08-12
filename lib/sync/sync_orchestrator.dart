import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/providers/database_provider.dart';
import '../data/repositories/attachment_repository.dart';
import '../data/repositories/note_repository.dart';
import '../data/repositories/sync_log_repository.dart';
import 'protocol/merge_resolver.dart';
import 'protocol/sync_bundle.dart';
import 'transport/nearby_service_transport.dart';
import 'transport/sync_transport.dart';

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
    this.error,
  });

  final SyncPhase phase;
  final List<SyncDevice> devices;
  final SyncDevice? selectedDevice;
  final int sentCount;
  final int totalCount;
  final int receivedCount;
  final List<SyncConflict> conflicts;
  final String? error;

  SyncOrchestratorState copyWith({
    SyncPhase? phase,
    List<SyncDevice>? devices,
    SyncDevice? selectedDevice,
    bool clearSelectedDevice = false,
    int? sentCount,
    int? totalCount,
    int? receivedCount,
    List<SyncConflict>? conflicts,
    String? error,
    bool clearError = false,
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
      error: clearError ? null : (error ?? this.error),
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

  NearbyServiceTransport? _transport;
  StreamSubscription? _deviceSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _bytesSub;
  StreamSubscription? _progressSub;
  String _localDeviceId = '';
  String _localDeviceName = '';

  /// Initializes the transport and gets local device info.
  ///
  /// Pass [testTransport] in tests to inject a fake.
  Future<void> initializeTransport(
      {NearbyServiceTransport? testTransport}) async {
    _transport = testTransport ?? NearbyServiceTransport();
    await _transport!.initialize();

    final info = await _transport!.getCurrentDeviceInfo();
    _localDeviceId = info?.id ?? const Uuid().v4();
    _localDeviceName = info?.displayName ?? 'Unknown Device';
  }

  /// Starts discovery for nearby devices (sender mode).
  Future<void> startDiscovery() async {
    if (_transport == null) await initializeTransport();

    // On Darwin, switch to browser role for discovery
    await _transport!.setDarwinBrowserRole();

    state = state.copyWith(phase: SyncPhase.discovering, clearError: true);

    unawaited(_deviceSub?.cancel());
    _deviceSub = _transport!.deviceFoundStream.listen((device) {
      final existing = state.devices;
      if (!existing.any((d) => d.deviceId == device.deviceId)) {
        state = state.copyWith(devices: [...existing, device]);
      }
    });

    unawaited(_stateSub?.cancel());
    _stateSub = _transport!.sessionStateStream.listen((sessionState) {
      if (sessionState.error != null) {
        state = state.copyWith(
          phase: SyncPhase.error,
          error: sessionState.error,
        );
      }
    });

    await _transport!.startDiscovery();
  }

  /// Starts advertising for incoming connections (receiver mode).
  Future<void> startAdvertising() async {
    if (_transport == null) await initializeTransport();

    // On Darwin, switch to advertiser role
    await _transport!.setDarwinAdvertiserRole();

    state = state.copyWith(phase: SyncPhase.receiving, clearError: true);
    await _transport!.startAdvertising();

    // Listen for incoming connections
    unawaited(_bytesSub?.cancel());
    _bytesSub = _transport!.bytesReceivedStream.listen(
      _handleReceivedBytes,
      onError: (e) {
        state = state.copyWith(
          phase: SyncPhase.error,
          error: 'Receive error: $e',
        );
      },
    );
  }

  /// Connects to a specific device and prepares for transfer.
  Future<void> connectToDevice(SyncDevice device) async {
    state = state.copyWith(
      phase: SyncPhase.connecting,
      selectedDevice: device,
    );

    final connected = await _transport!.connectToDevice(device.deviceId);
    if (!connected) {
      state = state.copyWith(
        phase: SyncPhase.error,
        error: 'Failed to connect to ${device.deviceName}',
      );
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

        // Attach first attachment file bytes (v1: single attachment per note).
        Uint8List? attachmentBytes;
        final attachments = await attachmentRepo.getAllForNote(noteId);
        if (attachments.isNotEmpty) {
          final file = File(attachments.first.filePath);
          if (file.existsSync()) {
            attachmentBytes = file.readAsBytesSync();
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
          attachmentBytes: attachmentBytes,
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

      // Send via transport
      await _transport!.sendData(bundleBytes);

      // Log each sent note
      final syncLog = SyncLogRepository(db);
      for (final entry in entries) {
        await syncLog.logSent(
          deviceId: _localDeviceId,
          deviceName: _localDeviceName,
          noteId: entry.noteId,
        );
      }

      // Increment syncVersion for sent notes
      for (final noteId in noteIds) {
        final note = await noteRepo.getNoteById(noteId);
        if (note != null) {
          await noteRepo.updateNote(
            noteId,
            syncVersion: note.syncVersion + 1,
          );
        }
      }

      state = state.copyWith(
        phase: SyncPhase.complete,
        sentCount: entries.length,
      );
    } catch (e) {
      state = state.copyWith(
        phase: SyncPhase.error,
        error: 'Send failed: $e',
      );
    }
  }

  /// Handles received CBOR bytes from the transport.
  Future<void> _handleReceivedBytes(List<int> bytes) async {
    state = state.copyWith(phase: SyncPhase.receiving);

    try {
      final bundle = SyncBundle.fromCbor(Uint8List.fromList(bytes));

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
            // Restore attachment bytes if present.
            if (entry.attachmentBytes != null) {
              final note = await noteRepo.getNoteById(entry.noteId);
              if (note != null) {
                final tempDir = Directory.systemTemp.createTempSync('sync_');
                final ext =
                    entry.noteFields['type'] == 'doodle' ? 'drawn' : 'img';
                final filePath = '${tempDir.path}/${entry.noteId}_att.$ext';
                await File(filePath).writeAsBytes(entry.attachmentBytes!);
                await attachmentRepo.addImage(
                  noteId: note.id,
                  filePath: filePath,
                );
              }
            }
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
        await resolver.applyIncoming(conflict.incoming);
        // Restore attachment if present.
        if (conflict.incoming.attachmentBytes != null) {
          final note = await noteRepo.getNoteById(conflict.incoming.noteId);
          if (note != null) {
            final tempDir = Directory.systemTemp.createTempSync('sync_');
            final ext = conflict.incoming.noteFields['type'] == 'doodle'
                ? 'drawn'
                : 'img';
            final filePath =
                '${tempDir.path}/${conflict.incoming.noteId}_att.$ext';
            await File(filePath)
                .writeAsBytes(conflict.incoming.attachmentBytes!);
            await attachmentRepo.addImage(
              noteId: note.id,
              filePath: filePath,
            );
          }
        }
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
        // Keep both — insert incoming as new
        await resolver.applyIncoming(conflict.incoming);
        // Restore attachment if present.
        if (conflict.incoming.attachmentBytes != null) {
          final note = await noteRepo.getNoteById(conflict.incoming.noteId);
          if (note != null) {
            final tempDir = Directory.systemTemp.createTempSync('sync_');
            final ext = conflict.incoming.noteFields['type'] == 'doodle'
                ? 'drawn'
                : 'img';
            final filePath =
                '${tempDir.path}/${conflict.incoming.noteId}_att.$ext';
            await File(filePath)
                .writeAsBytes(conflict.incoming.attachmentBytes!);
            await attachmentRepo.addImage(
              noteId: note.id,
              filePath: filePath,
            );
          }
        }
        await syncLog.logReceived(
          deviceId: conflict.incoming.deviceOriginId,
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
    unawaited(_deviceSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_bytesSub?.cancel());
    unawaited(_progressSub?.cancel());
    _deviceSub = null;
    _stateSub = null;
    _bytesSub = null;
    _progressSub = null;

    await _transport?.disconnect();
    state = const SyncOrchestratorState();
  }

  void dispose() {
    unawaited(_deviceSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_bytesSub?.cancel());
    unawaited(_progressSub?.cancel());
    _transport?.dispose();
  }
}

/// Provider for the sync orchestrator.
final syncOrchestratorProvider =
    NotifierProvider<SyncOrchestrator, SyncOrchestratorState>(
  SyncOrchestrator.new,
);

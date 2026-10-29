import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/features/sync_ui/sync_transfer_screen.dart';
import 'package:nook/features/sync_ui/widgets/conflict_card.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';
import 'package:nook/sync/sync_orchestrator.dart';

class _FixedStateOrchestrator extends SyncOrchestrator {
  _FixedStateOrchestrator(this._fixedState);
  final SyncOrchestratorState _fixedState;

  @override
  SyncOrchestratorState get state => _fixedState;

  @override
  SyncOrchestratorState build() => _fixedState;
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapWithState(SyncOrchestratorState state) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncOrchestratorProvider.overrideWith(
          () => _FixedStateOrchestrator(state),
        ),
      ],
      child: const MaterialApp(
        home: SyncTransferScreen(sessionId: 'test-session'),
      ),
    );
  }

  testWidgets('renders telemetry: speed, ETA, bytes, and item ticker',
      (tester) async {
    const stats = SyncProgressStats(
      stage: SyncStage.transferring,
      stageDescription: 'Streaming notes...',
      totalItems: 5,
      itemsTransferred: 2,
      totalBytes: 10485760, // 10 MB
      bytesTransferred: 5242880, // 5 MB
      bytesPerSecond: 1572864, // 1.5 MB/s
      estimatedTimeRemaining: Duration(seconds: 4),
      currentItemName: 'Vacation Plans',
    );

    const state = SyncOrchestratorState(
      phase: SyncPhase.sending,
      sentCount: 2,
      totalCount: 5,
      progressStats: stats,
    );

    await tester.pumpWidget(wrapWithState(state));
    await tester.pump();

    // Check header and counts
    expect(find.text('Beaming Notes...'), findsOneWidget);
    expect(find.text('2 of 5 sent'), findsOneWidget);

    // Check item name ticker
    expect(find.text('Vacation Plans'), findsOneWidget);

    // Check telemetry speed & ETA
    expect(find.textContaining('MB/s'), findsOneWidget);
    expect(find.textContaining('remaining'), findsOneWidget);
    expect(find.textContaining('5.0 MB of 10.0 MB'), findsOneWidget);
  });

  testWidgets('renders conflicts during resolving phase', (tester) async {
    final conflict = SyncConflict(
      incoming: SyncNoteEntry(
        noteId: 'conflicted-1',
        syncVersion: 2,
        updatedAt: DateTime.now(),
        deviceOriginId: 'remote-device',
        noteFields: {
          'title': 'Conflicted Meeting',
          'plainText': 'Remote details',
        },
      ),
      localDeviceName: 'Pixel 7',
      remoteDeviceName: 'Galaxy S24',
    );

    final state = SyncOrchestratorState(
      phase: SyncPhase.resolving,
      conflicts: [conflict],
    );

    await tester.pumpWidget(wrapWithState(state));
    await tester.pump();

    expect(find.byType(ConflictCard), findsOneWidget);
    expect(find.text('Conflict: Conflicted Meeting'), findsOneWidget);
    expect(find.text('Keep this device'), findsOneWidget);
    expect(find.text('Keep incoming'), findsOneWidget);
  });
}

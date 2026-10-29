import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/features/sync_ui/sync_screen.dart';
import 'package:nook/sync/sync_orchestrator.dart';
import 'package:nook/sync/transport/sync_transport.dart';

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
        home: SyncScreen(),
      ),
    );
  }

  testWidgets('shows discovered nearby devices on the sync hub',
      (tester) async {
    const device1 = SyncDevice(
      deviceId: 'peer-1',
      deviceName: 'MacBook Air',
      isOnline: true,
      multiaddresses: ['/ip4/192.168.1.10/udp/4001/udx'],
    );

    const state = SyncOrchestratorState(
      devices: [device1],
    );

    await tester.pumpWidget(wrapWithState(state));
    await tester.pump();

    expect(find.text('Nearby Devices (1)'), findsOneWidget);
    expect(find.text('MacBook Air'), findsOneWidget);
    expect(find.text('Send Notes'), findsOneWidget);
  });

  testWidgets('shows active transfer banner when sync is running',
      (tester) async {
    const stats = SyncProgressStats(
      stage: SyncStage.transferring,
      bytesPerSecond: 2097152, // 2 MB/s
      currentItemName: 'Important Note',
    );

    const state = SyncOrchestratorState(
      phase: SyncPhase.sending,
      sentCount: 1,
      totalCount: 3,
      progressStats: stats,
    );

    await tester.pumpWidget(wrapWithState(state));
    await tester.pump();

    expect(find.textContaining('Transfer in progress'), findsOneWidget);
    expect(find.textContaining('2.0 MB/s'), findsOneWidget);
    expect(find.text('View Transfer'), findsOneWidget);
  });
}

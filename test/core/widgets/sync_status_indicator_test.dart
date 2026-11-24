import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/widgets/sync_status_indicator.dart';
import 'package:nook/sync/sync_orchestrator.dart';
import 'package:nook/sync/transport/sync_transport.dart';
import 'package:nook/sync/protocol/sync_bundle.dart';

void main() {
  Widget buildIndicator({SyncOrchestratorState? state}) {
    return ProviderScope(
      overrides: [
        if (state != null)
          syncOrchestratorProvider
              .overrideWith(() => _MockSyncOrchestrator(state)),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: const [SyncStatusIndicator()],
          ),
        ),
      ),
    );
  }

  group('SyncStatusIndicator', () {
    testWidgets('renders idle state with checkmark icon', (tester) async {
      await tester.pumpWidget(buildIndicator(
        state: const SyncOrchestratorState(phase: SyncPhase.idle),
      ));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is HugeIcon &&
              w.icon == HugeIcons.strokeRoundedCheckmarkCircle01,
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Sync & devices · Synced'), findsOneWidget);
    });

    testWidgets('renders syncing state with wifi icon and device name',
        (tester) async {
      await tester.pumpWidget(buildIndicator(
        state: const SyncOrchestratorState(
          phase: SyncPhase.sending,
          selectedDevice: SyncDevice(
            deviceId: 'peer-1',
            deviceName: 'Pixel 9',
            isOnline: true,
          ),
        ),
      ));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedWifi01,
        ),
        findsOneWidget,
      );
      expect(
        find.byTooltip('Syncing with Pixel 9...'),
        findsOneWidget,
      );
    });

    testWidgets('renders conflict badge and count when conflicts exist',
        (tester) async {
      await tester.pumpWidget(buildIndicator(
        state: SyncOrchestratorState(
          conflicts: [
            SyncConflict(
              incoming: SyncNoteEntry(
                noteId: 'note-1',
                syncVersion: 1,
                updatedAt: DateTime.now(),
                deviceOriginId: 'remote-1',
                noteFields: const {'title': 'Remote Title'},
              ),
              localDeviceName: 'Laptop',
              remoteDeviceName: 'Phone',
            ),
            SyncConflict(
              incoming: SyncNoteEntry(
                noteId: 'note-2',
                syncVersion: 1,
                updatedAt: DateTime.now(),
                deviceOriginId: 'remote-1',
                noteFields: const {'title': 'Remote Title 2'},
              ),
              localDeviceName: 'Laptop',
              remoteDeviceName: 'Phone',
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedAlertCircle,
        ),
        findsOneWidget,
      );
      expect(find.text('2'), findsOneWidget);
      expect(
        find.byTooltip('Sync conflicts (2) · Tap to resolve'),
        findsOneWidget,
      );
    });

    testWidgets('renders error icon on sync error', (tester) async {
      await tester.pumpWidget(buildIndicator(
        state: const SyncOrchestratorState(
          phase: SyncPhase.error,
          error: 'Connection timed out',
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedAlertCircle,
        ),
        findsOneWidget,
      );
      expect(
        find.byTooltip('Sync error: Connection timed out'),
        findsOneWidget,
      );
    });

    testWidgets('satisfies minimum 48dp tap target', (tester) async {
      await tester.pumpWidget(buildIndicator(
        state: const SyncOrchestratorState(phase: SyncPhase.idle),
      ));
      await tester.pumpAndSettle();

      final target = tester.getSize(find.byType(SyncStatusIndicator));
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
    });
  });
}

class _MockSyncOrchestrator extends SyncOrchestrator {
  _MockSyncOrchestrator(this._initialState);

  final SyncOrchestratorState _initialState;

  @override
  SyncOrchestratorState build() => _initialState;
}

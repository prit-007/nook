import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/sync_ui/sync_history_screen.dart';
import 'package:nook/features/sync_ui/sync_pairing_screen.dart';
import 'package:nook/features/sync_ui/sync_receive_screen.dart';
import 'package:nook/features/sync_ui/sync_screen.dart';
import 'package:nook/features/sync_ui/sync_send_screen.dart';
import 'package:nook/features/sync_ui/sync_transfer_screen.dart';
import 'package:nook/features/sync_ui/widgets/conflict_card.dart';
import 'package:nook/sync/crypto/identity_store.dart';
import 'package:nook/sync/sync_orchestrator.dart';
import 'package:nook/sync/transport/sync_transport.dart';
import 'package:qr_flutter/qr_flutter.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

Widget wrapInApp(Widget child, {AppDatabase? db}) {
  final testDb = db ?? createTestDb();
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(testDb),
      syncOrchestratorProvider.overrideWith(() => _StubSyncOrchestrator()),
    ],
    child: MaterialApp(
      home: child is Scaffold ? child : SizedBox.expand(child: child),
    ),
  );
}

/// Wraps a screen with an orchestrator pinned to [state] (outcome tests).
Widget _wrapWithOrchestrator(SyncOrchestratorState state, {AppDatabase? db}) {
  final testDb = db ?? createTestDb();
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(testDb),
      syncOrchestratorProvider.overrideWith(
        () => _FixedStateOrchestrator(state),
      ),
    ],
    child: const MaterialApp(home: SyncTransferScreen(sessionId: 'session-1')),
  );
}

/// Wraps the [SyncSendScreen] with an orchestrator pinned to [state].
Widget _wrapSendWithState(SyncOrchestratorState state, {AppDatabase? db}) {
  final testDb = db ?? createTestDb();
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(testDb),
      syncOrchestratorProvider.overrideWith(
        () => _FixedStateOrchestrator(state),
      ),
    ],
    child: const MaterialApp(home: SyncSendScreen()),
  );
}

/// Wraps the [SyncReceiveScreen] with an orchestrator pinned to [state].
Widget _wrapReceiveWithState(
  SyncOrchestratorState state, {
  AppDatabase? db,
  List<String> localMultiaddresses = const [],
}) {
  final testDb = db ?? createTestDb();
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(testDb),
      syncOrchestratorProvider.overrideWith(
        () => _FixedStateOrchestrator(
          state,
          localMultiaddresses: localMultiaddresses,
        ),
      ),
    ],
    child: const MaterialApp(home: SyncReceiveScreen()),
  );
}

/// An orchestrator that always reports a fixed state.
class _FixedStateOrchestrator extends SyncOrchestrator {
  _FixedStateOrchestrator(
    this._fixedState, {
    this.localMultiaddresses = const [],
  });

  final SyncOrchestratorState _fixedState;
  @override
  final List<String> localMultiaddresses;

  @override
  SyncOrchestratorState build() => _fixedState;

  @override
  Future<void> startDiscovery() async {}

  @override
  Future<void> startAdvertising() async {}

  @override
  Future<void> stop() async {}
}

/// A stub orchestrator that does nothing (for widget tests).
class _StubSyncOrchestrator extends SyncOrchestrator {
  @override
  SyncOrchestratorState build() => const SyncOrchestratorState();

  @override
  Future<void> initializeTransport(
      {SyncTransport? testTransport,
      String? localDeviceName,
      bool useTcpFallback = false,
      IdentityStore? identityStore,
      String? listenAddress,
      bool discoveryNetworkEnabled = true}) async {}

  @override
  Future<void> startDiscovery() async {}

  @override
  Future<void> startAdvertising() async {}

  @override
  Future<void> stop() async {}
}

GoRouter testRouter(Widget child, {AppDatabase? db}) {
  final testDb = db ?? createTestDb();
  return GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(
        path: '/test',
        builder: (context, state) => ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: child,
        ),
      ),
      GoRoute(
        path: '/sync/send',
        builder: (context, state) => ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const SyncSendScreen(),
        ),
      ),
      GoRoute(
        path: '/sync/receive',
        builder: (context, state) => ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const SyncReceiveScreen(),
        ),
      ),
      GoRoute(
        path: '/sync/pairing',
        builder: (context, state) => ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const SyncPairingScreen(
            pairingCode: '000000',
            deviceName: 'Test Device',
          ),
        ),
      ),
      GoRoute(
        path: '/sync/transfer/:sessionId',
        builder: (context, state) => ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: SyncTransferScreen(
            sessionId: state.pathParameters['sessionId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/sync/history',
        builder: (context, state) => ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(testDb),
          ],
          child: const SyncHistoryScreen(),
        ),
      ),
    ],
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDb();
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncScreen', () {
    testWidgets('renders with Send and Receive buttons', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncScreen(), db: db));
      await tester.pump();

      expect(find.text('Send to Device'), findsOneWidget);
      expect(find.text('Receive Notes'), findsOneWidget);
    });

    testWidgets('shows sync icon in app bar', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncScreen(), db: db));
      await tester.pump();

      expect(
          find.byWidgetPredicate((w) =>
              w is HugeIcon && w.icon == HugeIcons.strokeRoundedSendToMobile),
          findsOneWidget);
    });

    testWidgets('shows sync history button', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncScreen(), db: db));
      await tester.pump();

      expect(
          find.byWidgetPredicate((w) =>
              w is HugeIcon &&
              w.icon == HugeIcons.strokeRoundedTransactionHistory),
          findsOneWidget);
    });
  });

  group('SyncSendScreen', () {
    testWidgets('renders with radar title', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncSendScreen(), db: db));
      await tester.pump();

      expect(find.text('Radar'), findsOneWidget);
    });

    testWidgets('shows empty state when no notes', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncSendScreen(), db: db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Vault is empty.'), findsOneWidget);
    });

    testWidgets('shows manual connection action', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncSendScreen(), db: db));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedLink01),
        findsOneWidget,
      );
    });

    testWidgets('shows the Send via QR action', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncSendScreen(), db: db));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedQrCode),
        findsOneWidget,
      );
    });

    testWidgets(
        'manual connection dialog exposes QR scanning on camera platforms',
        (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncSendScreen(), db: db));
      await tester.pump();

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedLink01,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Add device manually'), findsOneWidget);
      expect(find.text('Scan QR'), findsOneWidget);
    });

    testWidgets('shows discovered peers as floating orbs', (tester) async {
      await tester.pumpWidget(
        _wrapSendWithState(
          const SyncOrchestratorState(
            phase: SyncPhase.discovering,
            devices: [
              SyncDevice(
                deviceId: 'peer-1',
                deviceName: 'Galaxy S24',
                isOnline: true,
              ),
              SyncDevice(
                deviceId: 'peer-2',
                deviceName: 'MacBook',
                isOnline: true,
              ),
            ],
          ),
          db: db,
        ),
      );
      await tester.pump();

      expect(find.text('Galaxy S24'), findsOneWidget);
      expect(find.text('MacBook'), findsOneWidget);
      expect(find.text('Tap a device to send'), findsOneWidget);
    });

    testWidgets('tapping a peer with no selection shows a snackbar',
        (tester) async {
      await tester.pumpWidget(
        _wrapSendWithState(
          const SyncOrchestratorState(
            phase: SyncPhase.discovering,
            devices: [
              SyncDevice(
                deviceId: 'peer-1',
                deviceName: 'Galaxy S24',
                isOnline: true,
              ),
            ],
          ),
          db: db,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Galaxy S24'));
      await tester.pump();

      expect(find.text('Select at least one note below.'), findsOneWidget);
    });

    testWidgets('shows payload count when notes are selected', (tester) async {
      for (var i = 0; i < 2; i++) {
        await db.into(db.notes).insert(
              NotesCompanion.insert(
                id: Value('sel-note-$i'),
                type: NoteType.text,
                title: Value('Selected Note $i'),
                deviceOriginId: 'device-1',
              ),
            );
      }

      await tester.pumpWidget(wrapInApp(const SyncSendScreen(), db: db));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('2 Notes Ready'), findsOneWidget);
      expect(find.text('Selected Note 0'), findsOneWidget);
    });

    testWidgets('note list tiles keep ink splashes visible', (tester) async {
      // The note list lives inside a frosted, colored scroll region. Regression
      // guard: the region must place a Material between the tiles and the
      // translucent DecoratedBox so ListTiles can paint their ink/selection
      // highlights — otherwise Flutter throws the "ListTile background color or
      // ink splashes may be invisible" assertion.
      for (var i = 0; i < 4; i++) {
        await db.into(db.notes).insert(
              NotesCompanion.insert(
                id: Value('sync-note-$i'),
                type: NoteType.text,
                title: Value('Sync Note $i'),
                deviceOriginId: 'device-1',
              ),
            );
      }

      final errors = <FlutterErrorDetails>[];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(wrapInApp(const SyncSendScreen(), db: db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final inkErrors = errors.where((e) => e.toString().contains(
            'ListTile background color or ink splashes may be invisible',
          ));
      expect(inkErrors, isEmpty);
      expect(find.text('Sync Note 0'), findsOneWidget);
    });
  });

  group('SyncReceiveScreen', () {
    testWidgets('renders with the broadcasting beacon when idle',
        (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncReceiveScreen(), db: db));
      await tester.pump();

      expect(find.text('Invisible'), findsOneWidget);
      expect(find.text('Tap the icon to start broadcasting.'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedWifiOff01),
        findsOneWidget,
      );
    });

    testWidgets('shows visible beacon while discoverable', (tester) async {
      await tester.pumpWidget(
        _wrapReceiveWithState(
          const SyncOrchestratorState(phase: SyncPhase.complete),
          db: db,
        ),
      );
      await tester.pump();

      expect(find.text('Visible to nearby devices'), findsOneWidget);
      expect(find.text('Waiting for incoming transfers...'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedWifi01),
        findsOneWidget,
      );
    });

    testWidgets('shows a QR code for the receiver multiaddr', (tester) async {
      const address = '/ip4/192.168.1.20/udp/52341/udx/p2p/12D3KooWQrReceiver';
      await tester.pumpWidget(
        _wrapReceiveWithState(
          const SyncOrchestratorState(),
          db: db,
          localMultiaddresses: [address],
        ),
      );
      await tester.pump();

      // Start advertising so the receive screen copies addresses from the
      // transport and reveals the QR action.
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedWifiOff01,
        ),
      );
      await tester.pump();

      expect(find.text('QR Code'), findsOneWidget);
      await tester.tap(find.text('QR Code'));
      await tester.pumpAndSettle();

      expect(find.text('Scan to connect'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text(address), findsNWidgets(2));
    });

    testWidgets('tapping the beacon does not crash', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncReceiveScreen(), db: db));
      await tester.pump();

      await tester.tap(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedWifiOff01),
      );
      await tester.pump();

      expect(find.text('Invisible'), findsOneWidget);
    });

    testWidgets('shows a Scan QR action for camera platforms', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncReceiveScreen(), db: db));
      await tester.pump();

      // The prominent "scan a sender's QR code" action sits right under the
      // beacon on camera platforms — no advertising needed to reveal it.
      expect(find.text("Scan a sender's QR code"), findsOneWidget);
    });
  });

  group('SyncPairingScreen', () {
    testWidgets('renders with numeric code display', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SyncPairingScreen(
          pairingCode: '123456',
          deviceName: 'Galaxy S24',
        ),
        db: db,
      ));
      await tester.pump();

      expect(find.text('123456'), findsOneWidget);
      expect(find.textContaining('Galaxy S24'), findsOneWidget);
    });

    testWidgets('shows confirm and cancel buttons', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SyncPairingScreen(
          pairingCode: '123456',
          deviceName: 'Galaxy S24',
        ),
        db: db,
      ));
      await tester.pump();

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets(
        'keeps the PIN visible and waits while onConfirm is in flight '
        '(mutual confirmation)', (tester) async {
      var confirmCalls = 0;
      final completer = Completer<bool>();
      await tester.pumpWidget(wrapInApp(
        SyncPairingScreen(
          pairingCode: '123456',
          deviceName: 'Galaxy S24',
          onConfirm: () {
            confirmCalls++;
            return completer.future;
          },
        ),
        db: db,
      ));
      await tester.pump();

      await tester.tap(find.text('Confirm'));
      await tester.pump();

      // The code stays visible and the screen reports waiting — it must not
      // disappear just because the sender confirmed.
      expect(confirmCalls, 1);
      expect(find.text('123456'), findsOneWidget);
      expect(find.textContaining('Waiting for'), findsOneWidget);
      expect(find.text('Confirm'), findsNothing,
          reason: 'confirm is replaced by a spinner while waiting');

      // Both devices accept the same code → the screen pops with true.
      completer.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(SyncPairingScreen), findsNothing);
    });

    testWidgets('shows an error and stays open when onConfirm fails',
        (tester) async {
      await tester.pumpWidget(wrapInApp(
        SyncPairingScreen(
          pairingCode: '123456',
          deviceName: 'Galaxy S24',
          onConfirm: () async => false,
        ),
        db: db,
      ));
      await tester.pump();

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(find.text('123456'), findsOneWidget);
      expect(find.textContaining('Connection failed'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget,
          reason: 'the user can retry after a failed connection');
    });
  });

  group('SyncTransferScreen', () {
    testWidgets('renders with progress indicator', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SyncTransferScreen(sessionId: 'session-1'),
        db: db,
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows idle status text', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SyncTransferScreen(sessionId: 'session-1'),
        db: db,
      ));
      await tester.pump();

      expect(find.text('Establishing Link...'), findsOneWidget);
    });
  });

  group('SyncTransferScreen outcomes', () {
    testWidgets('rejected shows Transfer Declined, dismiss only',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithOrchestrator(
          const SyncOrchestratorState(
            phase: SyncPhase.error,
            error: 'Pairing rejected',
            outcome: SyncOutcomeCategory.rejected,
          ),
          db: db,
        ),
      );
      await tester.pump();

      expect(find.text('Transfer Declined'), findsOneWidget);
      expect(find.text('Pairing rejected'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Try Again'), findsNothing);
    });

    testWidgets('timedOut shows Transfer Timed Out with a retry',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithOrchestrator(
          const SyncOrchestratorState(
            phase: SyncPhase.error,
            error: 'Timed out waiting for ack',
            outcome: SyncOutcomeCategory.timedOut,
          ),
          db: db,
        ),
      );
      await tester.pump();

      expect(find.text('Transfer Timed Out'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
    });

    testWidgets('connectionLost shows Connection Lost with a retry',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithOrchestrator(
          const SyncOrchestratorState(
            phase: SyncPhase.error,
            error: 'Connection lost',
            outcome: SyncOutcomeCategory.connectionLost,
          ),
          db: db,
        ),
      );
      await tester.pump();

      expect(find.text('Connection Lost'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('internal keeps the generic Transfer Failed', (tester) async {
      await tester.pumpWidget(
        _wrapWithOrchestrator(
          const SyncOrchestratorState(
            phase: SyncPhase.error,
            error: 'Send failed',
            outcome: SyncOutcomeCategory.internal,
          ),
          db: db,
        ),
      );
      await tester.pump();

      expect(find.text('Transfer Failed'), findsOneWidget);
      expect(find.text('Try Again'), findsNothing);
    });

    testWidgets('cancelled shows Transfer Cancelled', (tester) async {
      await tester.pumpWidget(
        _wrapWithOrchestrator(
          const SyncOrchestratorState(
            phase: SyncPhase.error,
            error: 'Cancelled',
            outcome: SyncOutcomeCategory.cancelled,
          ),
          db: db,
        ),
      );
      await tester.pump();

      expect(find.text('Transfer Cancelled'), findsOneWidget);
      expect(find.text('Try Again'), findsNothing);
    });
  });

  group('ConflictCard', () {
    testWidgets('renders conflict information', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const ConflictCard(
          noteTitle: 'Groceries',
          localDeviceName: 'This device',
          remoteDeviceName: 'Galaxy S24',
        ),
        db: db,
      ));
      await tester.pump();

      expect(find.text('Conflict: Groceries'), findsOneWidget);
      expect(find.textContaining('This device'), findsNWidgets(2));
      expect(find.textContaining('Galaxy S24'), findsOneWidget);
    });

    testWidgets('shows three resolution options', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const ConflictCard(
          noteTitle: 'Groceries',
          localDeviceName: 'This device',
          remoteDeviceName: 'Galaxy S24',
        ),
        db: db,
      ));
      await tester.pump();

      expect(find.text('Keep this device'), findsOneWidget);
      expect(find.text('Keep incoming'), findsOneWidget);
      expect(find.text('Keep both'), findsOneWidget);
    });
  });

  group('SyncHistoryScreen', () {
    testWidgets('renders with history list', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncHistoryScreen(), db: db));
      await tester.pump();

      expect(find.text('Sync History'), findsOneWidget);
    });

    testWidgets('shows empty state when no history', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncHistoryScreen(), db: db));
      await tester.pump();

      expect(find.text('No sync history yet'), findsOneWidget);
    });
  });
}

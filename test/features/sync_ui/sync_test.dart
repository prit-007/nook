import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/features/sync_ui/sync_history_screen.dart';
import 'package:nook/features/sync_ui/sync_pairing_screen.dart';
import 'package:nook/features/sync_ui/sync_receive_screen.dart';
import 'package:nook/features/sync_ui/sync_screen.dart';
import 'package:nook/features/sync_ui/sync_send_screen.dart';
import 'package:nook/features/sync_ui/sync_transfer_screen.dart';
import 'package:nook/features/sync_ui/widgets/conflict_card.dart';
import 'package:nook/sync/sync_orchestrator.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

Widget wrapInApp(Widget child, {AppDatabase? db}) {
  final testDb = db ?? createTestDb();
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(testDb),
      syncOrchestratorProvider.overrideWith(() => _StubSyncOrchestrator()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

/// A stub orchestrator that does nothing (for widget tests).
class _StubSyncOrchestrator extends SyncOrchestrator {
  @override
  SyncOrchestratorState build() => const SyncOrchestratorState();

  @override
  Future<void> initializeTransport({dynamic testTransport}) async {}

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
      await tester.pumpAndSettle();

      expect(find.text('Send Notes'), findsOneWidget);
      expect(find.text('Receive Notes'), findsOneWidget);
    });

    testWidgets('shows sync icon in app bar', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncScreen(), db: db));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('shows sync history button', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncScreen(), db: db));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.history), findsOneWidget);
    });
  });

  group('SyncSendScreen', () {
    testWidgets('renders with note selection list', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncSendScreen(), db: db));
      await tester.pumpAndSettle();

      expect(find.text('Select Notes'), findsOneWidget);
    });

    testWidgets('shows empty state when no notes', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncSendScreen(), db: db));
      await tester.pumpAndSettle();

      expect(find.text('No notes to sync'), findsOneWidget);
    });

    testWidgets('shows search bar for filtering notes', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncSendScreen(), db: db));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });

  group('SyncReceiveScreen', () {
    testWidgets('renders with discoverable toggle', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncReceiveScreen(), db: db));
      await tester.pumpAndSettle();

      expect(find.text('Make this device visible'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('shows device name', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncReceiveScreen(), db: db));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.phone_android), findsOneWidget);
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
      await tester.pumpAndSettle();

      expect(find.text('123456'), findsOneWidget);
      expect(find.text('Galaxy S24'), findsOneWidget);
    });

    testWidgets('shows confirm and cancel buttons', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SyncPairingScreen(
          pairingCode: '123456',
          deviceName: 'Galaxy S24',
        ),
        db: db,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
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

    testWidgets('shows transfer status text', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SyncTransferScreen(sessionId: 'session-1'),
        db: db,
      ));
      await tester.pump();

      expect(find.text('Preparing transfer...'), findsOneWidget);
    });

    testWidgets('shows cancel button', (tester) async {
      await tester.pumpWidget(wrapInApp(
        const SyncTransferScreen(sessionId: 'session-1'),
        db: db,
      ));
      await tester.pump();

      expect(find.text('Cancel'), findsOneWidget);
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
      await tester.pumpAndSettle();

      expect(find.text('Conflict: Groceries'), findsOneWidget);
      expect(find.textContaining('This device'), findsOneWidget);
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
      await tester.pumpAndSettle();

      expect(find.text('Keep this device'), findsOneWidget);
      expect(find.text('Keep incoming'), findsOneWidget);
      expect(find.text('Keep both'), findsOneWidget);
    });
  });

  group('SyncHistoryScreen', () {
    testWidgets('renders with history list', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncHistoryScreen(), db: db));
      await tester.pumpAndSettle();

      expect(find.text('Sync History'), findsOneWidget);
    });

    testWidgets('shows empty state when no history', (tester) async {
      await tester.pumpWidget(wrapInApp(const SyncHistoryScreen(), db: db));
      await tester.pumpAndSettle();

      expect(find.text('No sync history yet'), findsOneWidget);
    });
  });
}

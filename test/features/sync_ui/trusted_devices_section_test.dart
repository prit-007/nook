import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/trusted_device_repository.dart';
import 'package:nook/features/sync_ui/sync_screen.dart';
import 'package:nook/sync/sync_orchestrator.dart';

class _StubSyncOrchestrator extends SyncOrchestrator {
  @override
  SyncOrchestratorState build() => const SyncOrchestratorState();
}

Widget wrapWithDb(Widget child, AppDatabase db,
    {List<TrustedDevice>? devices}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      syncOrchestratorProvider.overrideWith(() => _StubSyncOrchestrator()),
      if (devices != null)
        trustedDevicesProvider.overrideWith((ref) => devices),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  late AppDatabase db;
  late TrustedDeviceRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrustedDeviceRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncScreen Trusted Devices Section (TDD)', () {
    testWidgets(
        'renders Trusted Devices header and empty state when none exist',
        (tester) async {
      await tester.pumpWidget(wrapWithDb(const SyncScreen(), db, devices: []));
      await tester.pumpAndSettle();

      expect(find.text('Trusted Devices'), findsOneWidget);
      expect(
        find.text(
            'No trusted devices yet. Paired devices will appear here for fast 1-tap sync.'),
        findsOneWidget,
      );
    });

    testWidgets('renders trusted devices and toggles auto-sync',
        (tester) async {
      final device = await repo.addOrUpdateTrustedDevice(
        peerId: 'peer-alpha-1234',
        deviceName: 'MacBook Air M2',
      );

      await tester
          .pumpWidget(wrapWithDb(const SyncScreen(), db, devices: [device]));
      await tester.pumpAndSettle();

      expect(find.text('MacBook Air M2'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // Toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(await repo.isDeviceTrusted('peer-alpha-1234'), isFalse);
    });

    testWidgets('can remove / untrust a device', (tester) async {
      final device = await repo.addOrUpdateTrustedDevice(
        peerId: 'peer-beta-5678',
        deviceName: 'Pixel 8 Pro',
      );

      await tester
          .pumpWidget(wrapWithDb(const SyncScreen(), db, devices: [device]));
      await tester.pumpAndSettle();

      expect(find.text('Pixel 8 Pro'), findsOneWidget);

      final deleteIcon = find.byWidgetPredicate(
        (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedDelete02,
      );
      expect(deleteIcon, findsOneWidget);

      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Untrust Device'), findsOneWidget);
      await tester.tap(find.text('Untrust'));
      await tester.pumpAndSettle();

      expect(await repo.getTrustedDeviceByPeerId('peer-beta-5678'), isNull);
    });
  });
}

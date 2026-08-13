import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/core/widgets/semantics.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/tag_repository.dart';
import 'package:nook/features/editor/widgets/color_picker_sheet.dart';
import 'package:nook/features/sync_ui/sync_screen.dart';
import 'package:nook/features/tags/tag_detail_screen.dart';
import 'package:nook/sync/sync_orchestrator.dart';
import 'package:nook/sync/transport/sync_transport.dart';

/// A stub orchestrator that does nothing (for widget tests).
class _StubSyncOrchestrator extends SyncOrchestrator {
  @override
  SyncOrchestratorState build() => const SyncOrchestratorState();

  @override
  Future<void> initializeTransport(
      {SyncTransport? testTransport, String? localDeviceName}) async {}

  @override
  Future<void> startDiscovery() async {}

  @override
  Future<void> startAdvertising() async {}

  @override
  Future<void> stop() async {}
}

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  group('NookSemantics', () {
    test('contrastForeground returns white for dark swatches', () {
      expect(NookSemantics.contrastForeground(Colors.black), Colors.white);
      expect(
        NookSemantics.contrastForeground(const Color(0xFF1A237E)),
        Colors.white,
      );
    });

    test('contrastForeground returns near-black for light swatches', () {
      expect(
        NookSemantics.contrastForeground(Colors.white),
        Colors.black87,
      );
      expect(
        NookSemantics.contrastForeground(const Color(0xFFFFF3E0)),
        Colors.black87,
      );
    });

    testWidgets('iconButton exposes a semantic label and button role',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NookSemantics.iconButton(
              label: 'Add note',
              icon: Icons.add,
              onPressed: () {},
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.bySemanticsLabel('Add note'));
      expect(
        node,
        matchesSemantics(
          isButton: true,
          label: 'Add note',
        ),
      );
      handle.dispose();
    });

    testWidgets('tappable exposes label and tap action', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NookSemantics.tappable(
                label: 'Send to Device A',
                onTap: () {},
                child: const SizedBox(width: 100, height: 50),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Send to Device A')),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('hideFromSemantics excludes its subtree', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Visible label'),
                NookSemantics.hideFromSemantics(
                  const Text('Hidden label'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Visible label'), findsOneWidget);
      expect(find.bySemanticsLabel('Hidden label'), findsNothing);
      handle.dispose();
    });
  });

  group('Color swatch contrast', () {
    testWidgets('selected swatch check icon uses a contrasting color',
        (tester) async {
      // Indigo seed (#4355B9) is a dark swatch.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ColorPickerSheet(currentSeed: '#4355B9'),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(Icons.check));
      // Indigo is dark; the check must be white, never black-on-dark.
      expect(icon.color, Colors.white);
    });
  });

  group('Tag detail back button', () {
    testWidgets('exposes a Go back tooltip/label', (tester) async {
      final db = createTestDb();
      addTearDown(db.close);
      final repo = TagRepository(db);
      final tag = await repo.createTag(
        name: 'Ideas',
        colorSeed: '#2196F3',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: TagDetailScreen(tagId: tag.id),
          ),
        ),
      );
      // EmptyState (animate: true) loops forever; use a fixed pump.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byTooltip('Go back'), findsOneWidget);
    });
  });

  group('Sync device semantics', () {
    testWidgets('SyncScreen glass-mode cards carry a label', (tester) async {
      final db = createTestDb();
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            syncOrchestratorProvider
                .overrideWith(() => _StubSyncOrchestrator()),
          ],
          child: const MaterialApp(home: SyncScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Send to Device'), findsOneWidget);

      // The glass-mode cards must expose a Semantics button label.
      final labeledButtons = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Send to Device',
      );
      expect(labeledButtons, findsOneWidget);
    });
  });
}

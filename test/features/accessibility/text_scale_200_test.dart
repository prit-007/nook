import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/widgets/app_shell.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/home_screen.dart';
import 'package:nook/features/home/providers/note_card_metadata_provider.dart';
import 'package:nook/features/home/providers/notes_list_provider.dart';
import 'package:nook/features/home/widgets/nook_hero.dart';
import 'package:nook/features/home/widgets/note_compact_tile.dart';
import 'package:nook/features/onboarding/onboarding_screen.dart';
import 'package:nook/features/security/lock_screen.dart';
import 'package:nook/features/security/pin_entry_screen.dart';
import 'package:nook/features/settings/settings_appearance_screen.dart';
import 'package:nook/features/settings/settings_security_screen.dart';
import 'package:nook/features/sync_ui/sync_transfer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrapWithTextScale(Widget child, {double scale = 2.0}) {
    return ProviderScope(
      overrides: [
        notesListProvider.overrideWith((ref) => Stream.value(<Note>[])),
        checklistItemsRevisionProvider
            .overrideWith((ref) => const Stream<void>.empty()),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(scale),
            size: const Size(412, 915),
            disableAnimations: true,
          ),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('200% Text Scaling Accessibility Audit', () {
    testWidgets(
        'HomeScreen renders cleanly at 200% text scale without overflow',
        (tester) async {
      await tester
          .pumpWidget(wrapWithTextScale(const HomeScreen(animate: false)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'SettingsSecurityScreen renders cleanly at 200% text scale without overflow',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTextScale(const SettingsSecurityScreen()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'SettingsAppearanceScreen renders cleanly at 200% text scale without overflow',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTextScale(const SettingsAppearanceScreen()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'NoteCompactTile renders cleanly at 200% text scale without overflow',
        (tester) async {
      final now = DateTime(2026, 11, 24);
      final note = Note(
        id: 'scale-note-1',
        title:
            'Very Long Title For Note That Might Exceed Bounds At High Scale',
        type: NoteType.text,
        pinned: true,
        locked: true,
        archived: false,
        deleted: false,
        syncVersion: 1,
        deviceOriginId: 'local',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        wrapWithTextScale(
          NoteCompactTile(
            note: note,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'NookHeroSliver renders cleanly at 200% text scale without overflow',
        (tester) async {
      NookHeroSliver.resetEntranceForTesting();
      await tester.pumpWidget(
        wrapWithTextScale(
          CustomScrollView(
            slivers: [
              NookHeroSliver(
                noteCount: 42,
                syncStatus: NookSyncStatus.synced,
                onSearch: () {},
                onSyncTap: () {},
                onCaptureText: () {},
                onCaptureChecklist: () {},
                onCaptureDoodle: () {},
                title: 'Nook',
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 200),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Your vault · 42 notes'), findsOneWidget);
    });

    testWidgets(
        'AppShell dock renders cleanly at 200% text scale with tap targets >= 48dp',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const AppShell(child: SizedBox()),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0),
                size: const Size(412, 915),
              ),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final dockItems = find.byType(InkResponse);
      expect(dockItems, findsWidgets);
      for (final item in dockItems.evaluate()) {
        final box = item.renderObject as RenderBox?;
        if (box != null && box.hasSize && box.size.height > 10) {
          expect(box.size.height, greaterThanOrEqualTo(48.0));
          expect(box.size.width, greaterThanOrEqualTo(48.0));
        }
      }
    });

    testWidgets('LockScreen renders cleanly at 200% text scale',
        (tester) async {
      await tester.pumpWidget(wrapWithTextScale(const LockScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'PinEntryScreen renders cleanly at 200% text scale with tap targets >= 48dp',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTextScale(
          const PinEntryScreen(isSetup: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final inkResponses = find.byType(InkResponse);
      for (final item in inkResponses.evaluate()) {
        final box = item.renderObject as RenderBox?;
        if (box != null && box.hasSize && box.size.height > 10) {
          expect(box.size.height, greaterThanOrEqualTo(48.0));
          expect(box.size.width, greaterThanOrEqualTo(48.0));
        }
      }
    });

    testWidgets('OnboardingScreen renders cleanly at 200% text scale',
        (tester) async {
      await tester.pumpWidget(wrapWithTextScale(const OnboardingScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('SyncTransferScreen renders cleanly at 200% text scale',
        (tester) async {
      await tester.pumpWidget(
        wrapWithTextScale(
          const SyncTransferScreen(sessionId: 'scale-session-test'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });
  });
}

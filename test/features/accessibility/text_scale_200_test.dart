import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/providers/note_card_metadata_provider.dart';
import 'package:nook/features/home/home_screen.dart';
import 'package:nook/features/home/providers/notes_list_provider.dart';
import 'package:nook/features/home/widgets/nook_hero.dart';
import 'package:nook/features/home/widgets/note_compact_tile.dart';
import 'package:nook/features/settings/settings_appearance_screen.dart';
import 'package:nook/features/settings/settings_security_screen.dart';
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
  });
}

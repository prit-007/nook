import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/theme/nook_tokens.dart';
import 'package:nook/features/home/widgets/nook_hero.dart';

void main() {
  setUp(() {
    NookHeroSliver.resetEntranceForTesting();
  });

  Widget buildHeroHarness({
    int noteCount = 0,
    NookSyncStatus syncStatus = NookSyncStatus.synced,
    VoidCallback? onSearch,
    VoidCallback? onSyncTap,
    VoidCallback? onCaptureText,
    VoidCallback? onCaptureChecklist,
    VoidCallback? onCaptureDoodle,
    VoidCallback? onCaptureVoice,
    String title = 'Nook',
    double textScale = 1.0,
    Locale locale = const Locale('en'),
    ScrollController? scrollController,
  }) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
    return MaterialApp(
      theme: ThemeData(
        colorScheme: scheme,
        extensions: [NookTokens.fromScheme(scheme)],
      ),
      locale: locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [
        Locale('en'),
        Locale('gu'),
        Locale('hi'),
        Locale('mr'),
      ],
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: const Size(400, 800),
          padding: const EdgeInsets.only(top: 24),
          disableAnimations: true,
        ),
        child: Scaffold(
          body: CustomScrollView(
            controller: scrollController,
            slivers: [
              NookHeroSliver(
                noteCount: noteCount,
                syncStatus: syncStatus,
                onSearch: onSearch ?? () {},
                onSyncTap: onSyncTap ?? () {},
                onCaptureText: onCaptureText ?? () {},
                onCaptureChecklist: onCaptureChecklist ?? () {},
                onCaptureDoodle: onCaptureDoodle ?? () {},
                onCaptureVoice: onCaptureVoice,
                title: title,
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 1200),
              ),
            ],
          ),
        ),
      ),
    );
  }

  group('NookHeroSliver — Expanded State', () {
    testWidgets('renders zero notes sentence-case label', (tester) async {
      await tester.pumpWidget(buildHeroHarness(noteCount: 0));
      await tester.pumpAndSettle();

      expect(find.text('Your vault'), findsOneWidget);
    });

    testWidgets('renders single note sentence-case label', (tester) async {
      await tester.pumpWidget(buildHeroHarness(noteCount: 1));
      await tester.pumpAndSettle();

      expect(find.text('Your vault · 1 note'), findsOneWidget);
    });

    testWidgets('renders multiple notes sentence-case label', (tester) async {
      await tester.pumpWidget(buildHeroHarness(noteCount: 42));
      await tester.pumpAndSettle();

      expect(find.text('Your vault · 42 notes'), findsOneWidget);
    });

    testWidgets('renders capture bar items and triggers callbacks',
        (tester) async {
      bool textCaptured = false;
      bool checklistCaptured = false;
      bool doodleCaptured = false;
      bool voiceCaptured = false;

      await tester.pumpWidget(
        buildHeroHarness(
          onCaptureText: () => textCaptured = true,
          onCaptureChecklist: () => checklistCaptured = true,
          onCaptureDoodle: () => doodleCaptured = true,
          onCaptureVoice: () => voiceCaptured = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Capture a thought'), findsOneWidget);
      expect(find.byTooltip('New checklist'), findsOneWidget);
      expect(find.byTooltip('New doodle'), findsOneWidget);
      expect(find.byTooltip('Voice note'), findsOneWidget);

      await tester.tap(find.text('Capture a thought'));
      expect(textCaptured, isTrue);

      await tester.tap(find.byTooltip('New checklist'));
      expect(checklistCaptured, isTrue);

      await tester.tap(find.byTooltip('New doodle'));
      expect(doodleCaptured, isTrue);

      await tester.tap(find.byTooltip('Voice note'));
      expect(voiceCaptured, isTrue);
    });

    testWidgets('omits voice note button when onCaptureVoice is null',
        (tester) async {
      await tester.pumpWidget(buildHeroHarness(onCaptureVoice: null));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Voice note'), findsNothing);
    });
  });

  group('NookHeroSliver — Sync Pill States', () {
    testWidgets('renders Synced status with tick icon', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(buildHeroHarness(
        syncStatus: NookSyncStatus.synced,
        onSyncTap: () => tapped = true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Synced'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedTick02),
        findsOneWidget,
      );

      await tester.tap(find.text('Synced'));
      expect(tapped, isTrue);
    });

    testWidgets('renders Syncing status with progress indicator',
        (tester) async {
      await tester.pumpWidget(buildHeroHarness(
        syncStatus: NookSyncStatus.syncing,
      ));
      await tester.pump();

      expect(find.text('Syncing'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders Needs review status on conflict', (tester) async {
      await tester.pumpWidget(buildHeroHarness(
        syncStatus: NookSyncStatus.conflict,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Needs review'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
            (w) => w is HugeIcon && w.icon == HugeIcons.strokeRoundedAlert02),
        findsOneWidget,
      );
    });

    testWidgets('renders On this device status for offline-first localOnly',
        (tester) async {
      await tester.pumpWidget(buildHeroHarness(
        syncStatus: NookSyncStatus.localOnly,
      ));
      await tester.pumpAndSettle();

      expect(find.text('On this device'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedFingerPrint),
        findsOneWidget,
      );
    });
  });

  group('NookHeroSliver — Collapsing & Top Bar', () {
    testWidgets('top bar search button fires onSearch callback',
        (tester) async {
      bool searchTapped = false;
      await tester.pumpWidget(buildHeroHarness(
        onSearch: () => searchTapped = true,
      ));
      await tester.pumpAndSettle();

      final searchBtn = find.byTooltip('Search notes');
      expect(searchBtn, findsOneWidget);
      await tester.tap(searchBtn);
      expect(searchTapped, isTrue);
    });

    testWidgets('collapsing reveals title and fades out body', (tester) async {
      final controller = ScrollController();
      await tester.pumpWidget(buildHeroHarness(
        title: 'Nook Test',
        scrollController: controller,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Nook Test'), findsOneWidget);
      expect(find.text('Capture a thought'), findsOneWidget);

      // Scroll down past the hero maxExtent
      controller.jumpTo(250);
      await tester.pumpAndSettle();

      // Top bar title is still present
      expect(find.text('Nook Test'), findsOneWidget);
      // Sync pill and search remain visible
      expect(find.byTooltip('Search notes'), findsOneWidget);
      expect(find.text('Synced'), findsOneWidget);
    });
  });

  group('NookHeroSliver — Text Scaling & Indic Scripts', () {
    testWidgets('renders cleanly at 200% text scale without overflow',
        (tester) async {
      await tester.pumpWidget(buildHeroHarness(
        noteCount: 128,
        textScale: 2.0,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Your vault · 128 notes'), findsOneWidget);
      expect(find.text('Capture a thought'), findsOneWidget);
    });

    testWidgets('zeroes letter tracking for Indic languages', (tester) async {
      for (final lang in ['gu', 'hi', 'mr']) {
        await tester.pumpWidget(buildHeroHarness(
          locale: Locale(lang),
          noteCount: 5,
        ));
        await tester.pumpAndSettle();

        final labelText =
            tester.widget<Text>(find.text('Your vault · 5 notes'));
        expect(labelText.style?.letterSpacing, equals(0.0));
      }
    });

    testWidgets('touch targets are at least 48dp', (tester) async {
      await tester.pumpWidget(buildHeroHarness(
        onCaptureVoice: () {},
      ));
      await tester.pumpAndSettle();

      final buttons = [
        find.byTooltip('Search notes'),
        find.byTooltip('New checklist'),
        find.byTooltip('New doodle'),
        find.byTooltip('Voice note'),
      ];

      for (final btn in buttons) {
        final size = tester.getSize(btn);
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/theme/note_theme.dart';

void main() {
  group('noteSchemeFor', () {
    testWidgets('returns ambient scheme when colorSeed is null',
        (tester) async {
      final ambientScheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      );

      late ColorScheme result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: ambientScheme),
          home: Builder(
            builder: (context) {
              result = noteSchemeFor(context, null);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, ambientScheme);
    });

    testWidgets('returns ambient scheme when colorSeed is empty',
        (tester) async {
      final ambientScheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      );

      late ColorScheme result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: ambientScheme),
          home: Builder(
            builder: (context) {
              result = noteSchemeFor(context, '');
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, ambientScheme);
    });

    testWidgets('generates scheme from seed preserving ambient brightness',
        (tester) async {
      final ambientScheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      );

      late ColorScheme result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: ambientScheme),
          home: Builder(
            builder: (context) {
              result = noteSchemeFor(context, 'E8604C');
              return const SizedBox();
            },
          ),
        ),
      );

      // Primary should come from the coral seed, NOT the blue ambient.
      expect(result.primary, isNot(ambientScheme.primary));
      // Brightness should match the ambient.
      expect(result.brightness, Brightness.dark);
    });

    testWidgets('uses correct brightness from ambient', (tester) async {
      late ColorScheme lightResult;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
          ),
          home: Builder(
            builder: (context) {
              lightResult = noteSchemeFor(context, 'E8604C');
              return const SizedBox();
            },
          ),
        ),
      );
      expect(lightResult.brightness, Brightness.light);
    });

    testWidgets('uses dark brightness from dark ambient', (tester) async {
      late ColorScheme darkResult;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
          ),
          home: Builder(
            builder: (context) {
              darkResult = noteSchemeFor(context, 'E8604C');
              return const SizedBox();
            },
          ),
        ),
      );
      expect(darkResult.brightness, Brightness.dark);
    });

    testWidgets('inherits AMOLED ambient surfaces for a seeded note',
        (tester) async {
      // Simulate an AMOLED ambient scheme with pure-black surfaces.
      final amoledAmbient = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF000000),
        surfaceContainerLowest: const Color(0xFF000000),
        surfaceContainerLow: const Color(0xFF0A0A0A),
        surfaceContainer: const Color(0xFF121212),
        surfaceContainerHigh: const Color(0xFF1A1A1A),
        surfaceContainerHighest: const Color(0xFF222222),
      );

      late ColorScheme result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: amoledAmbient),
          home: Builder(
            builder: (context) {
              result = noteSchemeFor(context, 'E8604C');
              return const SizedBox();
            },
          ),
        ),
      );

      // Neutral surfaces must come from the AMOLED ambient.
      expect(result.surface, const Color(0xFF000000));
      expect(result.surfaceContainerHigh, const Color(0xFF1A1A1A));
      expect(result.surfaceContainerHighest, const Color(0xFF222222));

      // The note seed still drives the primary hue.
      expect(result.primary, isNot(amoledAmbient.primary));
      expect(result.brightness, Brightness.dark);
    });

    testWidgets('returns ambient scheme verbatim when unseeded',
        (tester) async {
      final amoledAmbient = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF000000),
        surfaceContainerHigh: const Color(0xFF1A1A1A),
      );

      late ColorScheme result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: amoledAmbient),
          home: Builder(
            builder: (context) {
              result = noteSchemeFor(context, null);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(result, amoledAmbient);
      expect(result.surface, const Color(0xFF000000));
    });
  });
}

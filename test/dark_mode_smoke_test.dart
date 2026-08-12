import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/core/providers/theme_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/features/editor/note_editor_screen.dart';
import 'package:nook/features/home/home_screen.dart';
import 'package:nook/features/home/search_screen.dart';
import 'package:nook/features/notebooks/notebooks_screen.dart';
import 'package:nook/features/settings/settings_appearance_screen.dart';
import 'package:nook/features/tags/tags_screen.dart';
import 'package:nook/features/trash/trash_screen.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDb());
  tearDown(() async => db.close());

  Widget darkApp(Widget child) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          themePreferenceProvider.overrideWith(
            (_) => ThemePreference(themeMode: ThemeMode.dark),
          ),
        ],
        child: MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: child,
        ),
      );

  testWidgets('home screen renders in dark mode', (tester) async {
    await tester.pumpWidget(darkApp(const HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(Scaffold), findsOneWidget);
    await db.close();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('editor screen renders in dark mode', (tester) async {
    await tester.pumpWidget(darkApp(const NoteEditorScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('appearance screen renders in dark mode', (tester) async {
    await tester.pumpWidget(darkApp(const SettingsAppearanceScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('trash screen renders in dark mode', (tester) async {
    await tester.pumpWidget(darkApp(const TrashScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsOneWidget);
  });

  testWidgets('notebooks screen renders in dark mode', (tester) async {
    await tester.pumpWidget(darkApp(const NotebooksScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Notebooks'), findsOneWidget);
  });

  testWidgets('tags screen renders in dark mode', (tester) async {
    await tester.pumpWidget(darkApp(const TagsScreen()));
    // The tags empty-state animation loops forever; settle with fixed frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tags'), findsOneWidget);
  });

  testWidgets('search screen renders in dark mode', (tester) async {
    await tester.pumpWidget(darkApp(const SearchScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
  });
}

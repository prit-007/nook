import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/core/providers/note_type_preset_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/template_repository.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/widgets/note_creation_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NoteCreationSheet', () {
    testWidgets('combines NoteTypeMorphSelector, presets, and templates',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final db = createTestDatabase();
      addTearDown(db.close);
      await TemplateRepository(db).seedBuiltinsIfEmpty();
      final store = await NoteTypePresetStore.load();

      NoteCreationChoice? choice;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            noteTypePresetProvider.overrideWith((_) => store),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: NoteCreationSheet(
                onCreate: (c) => choice = c,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Story'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Sketch'), findsOneWidget);
      expect(find.text('Templates'), findsOneWidget);

      await tester.tap(find.text('Sketch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(choice?.type, NoteType.doodle);
      expect(choice?.preset.paperPattern, isNotNull);
    });
  });
}

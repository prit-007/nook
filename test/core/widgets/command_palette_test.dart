import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/commands/command_registry.dart';
import 'package:nook/core/widgets/command_palette.dart';
import 'package:nook/data/tables/notes.dart';

void main() {
  group('fuzzyScore / filterCommands', () {
    final commands = buildDefaultCommands(
      CommandPaletteActions(
        onCreateNote: (_) {},
        onFromTemplate: () {},
      ),
    );

    test('empty query returns all commands', () {
      expect(filterCommands(commands, '').length, commands.length);
    });

    test('substring match ranks by title', () {
      final hits = filterCommands(commands, 'new note');
      expect(hits, isNotEmpty);
      expect(hits.first.id, 'new-note');
    });

    test('keywords help matching', () {
      final hits = filterCommands(commands, 'biometric');
      expect(hits.map((c) => c.id), contains('security'));
    });

    test('no match returns empty', () {
      expect(filterCommands(commands, 'zzzz-nothing'), isEmpty);
    });

    test('fuzzy subsequence finds command', () {
      final hits = filterCommands(commands, 'trsh');
      expect(hits.map((c) => c.id), contains('trash'));
    });
  });

  group('CommandPaletteDialog', () {
    testWidgets('filters as you type and executes selection', (tester) async {
      var executed = '';
      final commands = buildDefaultCommands(
        CommandPaletteActions(
          onCreateNote: (_) {},
          onFromTemplate: () {},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showCommandPalette(
                    context,
                    commands: commands,
                    onExecute: (command, appContext) {
                      executed = command.id;
                    },
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Type a command…'), findsOneWidget);
      expect(find.text('New note'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'trash');
      await tester.pumpAndSettle();
      expect(find.text('Open trash / bin'), findsOneWidget);
      expect(find.text('New note'), findsNothing);

      await tester.tap(find.text('Open trash / bin'));
      await tester.pumpAndSettle();

      expect(executed, 'trash');
    });

    testWidgets('create-note commands expose NoteType to the host',
        (tester) async {
      NoteType? type;
      final commands = buildDefaultCommands(
        CommandPaletteActions(
          onCreateNote: (t) => type = t,
          onFromTemplate: () {},
        ),
      );
      final checklist = commands.firstWhere((c) => c.id == 'new-checklist');
      expect(checklist.onCreateNoteType, NoteType.checklist);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showCommandPalette(
                    context,
                    commands: commands,
                    onExecute: (command, appContext) {
                      final t = command.onCreateNoteType;
                      if (t != null) {
                        type = t;
                      } else {
                        command.onRun?.call(appContext);
                      }
                    },
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'checklist');
      await tester.pumpAndSettle();
      await tester.tap(find.text('New checklist'));
      await tester.pumpAndSettle();
      expect(type, NoteType.checklist);
    });
  });
}

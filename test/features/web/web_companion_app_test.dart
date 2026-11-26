import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/web/web_companion_app.dart';

void main() {
  test('parseWebCompanionFiles parses markdown, json, and zip archives', () {
    final archive = Archive()
      ..addFile(ArchiveFile.string('notes/Trip.md', '# Trip\nPack bags'));
    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

    final jsonBytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'notes': [
            {'id': 'n1', 'title': 'Backup Note', 'plainText': 'Hello web'},
          ],
        }),
      ),
    );

    final parsed = parseWebCompanionFiles([
      (name: 'export.zip', bytes: zipBytes),
      (name: 'vault.nook', bytes: jsonBytes),
      (
        name: 'scratch.md',
        bytes: Uint8List.fromList(utf8.encode('# Quick\nHi'))
      ),
    ]);

    expect(parsed.map((n) => n.title), ['Trip', 'Backup Note', 'Quick']);
  });

  testWidgets('WebCompanionApp renders read-only notes and filters them',
      (tester) async {
    await tester.pumpWidget(
      const WebCompanionApp(
        initialNotes: [
          WebCompanionNote(id: '1', title: 'Alpha', body: 'First body'),
          WebCompanionNote(id: '2', title: 'Beta', body: 'Second body'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First body'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Beta');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Beta'));
    await tester.pumpAndSettle();

    expect(find.text('Second body'), findsOneWidget);
  });
}

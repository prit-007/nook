import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/attachment_repository.dart';
import 'package:nook/data/repositories/doodle_storage.dart';
import 'package:nook/features/doodle/doodle_canvas_screen.dart';

AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

void main() {
  Widget buildScreen() {
    return const ProviderScope(
      child: MaterialApp(
        home: DoodleCanvasScreen(noteId: 'note-1'),
      ),
    );
  }

  testWidgets('restore freehand chip not shown when nothing selected',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    expect(
      find.textContaining('Restore freehand'),
      findsNothing,
    );
  });

  testWidgets('screen renders without errors', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump();

    // Close button should be present
    expect(
        find.byWidgetPredicate((w) =>
            w is HugeIcon && w.icon == HugeIcons.strokeRoundedCancelCircle),
        findsOneWidget);
  });
}

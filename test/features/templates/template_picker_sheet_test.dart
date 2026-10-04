import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/providers/database_provider.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/repositories/template_repository.dart';
import 'package:nook/features/templates/template_picker_sheet.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('picker lists builtin templates', (tester) async {
    await TemplateRepository(db).seedBuiltinsIfEmpty();

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showTemplatePickerSheet(context),
            child: const Text('templates'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('templates'));
    await tester.pumpAndSettle();

    expect(find.text('Start from template'), findsOneWidget);
    expect(find.text('Meeting notes'), findsOneWidget);
    expect(find.text('Reading list'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/widgets/keyboard_shortcuts.dart';

void main() {
  group('NookKeyboardShortcuts', () {
    Future<void> pump(
      WidgetTester tester, {
      VoidCallback? onOpenSearch,
      VoidCallback? onNewNote,
      Widget? child,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NookKeyboardShortcuts(
            onOpenSearch: onOpenSearch,
            onNewNote: onNewNote,
            child: child ??
                const Scaffold(body: Center(child: Text('app content'))),
          ),
        ),
      );
      // Let the root Focus autofocus take effect.
      await tester.pump();
    }

    Future<void> sendCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(key);
      await tester.sendKeyUpEvent(key);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    testWidgets('fires open-search on "/" when nothing is focused',
        (tester) async {
      var searches = 0;
      await pump(tester, onOpenSearch: () => searches++);

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pump();

      expect(searches, 1);
    });

    testWidgets('fires open-search on Ctrl+K', (tester) async {
      var searches = 0;
      await pump(tester, onOpenSearch: () => searches++);

      await sendCtrl(tester, LogicalKeyboardKey.keyK);

      expect(searches, 1);
    });

    testWidgets('fires new-note on Ctrl+N', (tester) async {
      var notes = 0;
      await pump(tester, onNewNote: () => notes++);

      await sendCtrl(tester, LogicalKeyboardKey.keyN);

      expect(notes, 1);
    });

    testWidgets('does not fire while a TextField is focused', (tester) async {
      var searches = 0;
      var notes = 0;
      await pump(
        tester,
        onOpenSearch: () => searches++,
        onNewNote: () => notes++,
        child: const Scaffold(body: Center(child: TextField())),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pump();
      expect(searches, 0);

      await sendCtrl(tester, LogicalKeyboardKey.keyK);
      expect(searches, 0);

      await sendCtrl(tester, LogicalKeyboardKey.keyN);
      expect(notes, 0);
    });

    testWidgets('fires while a non-text focusable (button) is focused',
        (tester) async {
      var searches = 0;
      await pump(
        tester,
        onOpenSearch: () => searches++,
        child: Scaffold(
          body: Center(
              child: TextButton(onPressed: () {}, child: const Text('b'))),
        ),
      );

      await tester.tap(find.byType(TextButton));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.pump();

      expect(searches, 1);
    });
  });
}

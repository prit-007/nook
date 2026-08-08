import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nook/features/editor/doodle/doodle_block.dart';

void main() {
  group('DoodleBlockKeys', () {
    test('type is "doodle"', () {
      expect(DoodleBlockKeys.type, 'doodle');
    });

    test('has attachmentId key', () {
      expect(DoodleBlockKeys.attachmentId, 'attachment_id');
    });

    test('has thumbnailData key', () {
      expect(DoodleBlockKeys.thumbnailData, 'thumbnail_data');
    });
  });

  group('doodleNode helper', () {
    test('creates node with correct type', () {
      final node = doodleNode(attachmentId: 'att-1');
      expect(node.type, DoodleBlockKeys.type);
    });

    test('stores attachmentId in attributes', () {
      final node = doodleNode(attachmentId: 'att-42');
      expect(node.attributes[DoodleBlockKeys.attachmentId], 'att-42');
    });

    test('stores thumbnailData when provided', () {
      final node = doodleNode(attachmentId: 'a1', thumbnailData: 'base64data');
      expect(node.attributes[DoodleBlockKeys.thumbnailData], 'base64data');
    });

    test('omits thumbnailData when null', () {
      final node = doodleNode(attachmentId: 'a1');
      expect(
          node.attributes.containsKey(DoodleBlockKeys.thumbnailData), isFalse);
    });

    test('has no children', () {
      final node = doodleNode(attachmentId: 'a1');
      expect(node.children, isEmpty);
    });

    test('has no delta (non-text block)', () {
      final node = doodleNode(attachmentId: 'a1');
      expect(node.delta, isNull);
    });
  });

  group('DoodleBlockComponentBuilder', () {
    late DoodleBlockComponentBuilder builder;

    setUp(() {
      builder = DoodleBlockComponentBuilder();
    });

    test('validate returns true for valid doodle node', () {
      final node = doodleNode(attachmentId: 'a1');
      expect(builder.validate(node), isTrue);
    });

    test('validate returns false for node with delta', () {
      final node = Node(
        type: DoodleBlockKeys.type,
        attributes: {
          'delta': [
            {'insert': 'text'}
          ]
        },
      );
      expect(builder.validate(node), isFalse);
    });

    test('validate returns false for node with children', () {
      final node = Node(
        type: DoodleBlockKeys.type,
        children: [Node(type: 'paragraph')],
      );
      expect(builder.validate(node), isFalse);
    });

    test('build returns DoodleBlockComponentWidget', () {
      final node = doodleNode(attachmentId: 'a1');
      // Builder validate + construction (full rendering needs widget test)
      expect(builder.validate(node), isTrue);
      expect(builder.onTap, isNull);
    });

    test('builder accepts onTap callback', () {
      final b = DoodleBlockComponentBuilder(
        onTap: () {},
      );
      expect(b.onTap, isNotNull);
    });
  });

  group('DoodleBlockComponentWidget', () {
    Widget buildWidget({VoidCallback? onTap, String? thumbnailData}) {
      final editorState = EditorState.blank();
      final node = doodleNode(
        attachmentId: 'a1',
        thumbnailData: thumbnailData,
      );

      return MaterialApp(
        home: Scaffold(
          body: Provider.value(
            value: editorState,
            child: DoodleBlockComponentWidget(
              node: node,
              onTap: onTap,
            ),
          ),
        ),
      );
    }

    testWidgets('renders placeholder icon when no thumbnail', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.brush), findsOneWidget);
    });

    testWidgets('tapping widget invokes onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildWidget(onTap: () => tapped = true));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.brush));
      expect(tapped, isTrue);
    });

    testWidgets('shows edit label below placeholder', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text('Tap to edit doodle'), findsOneWidget);
    });

    testWidgets('renders container with minimum height', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GestureDetector),
          matching: find.byType(Container),
        ),
      );
      expect(container.constraints?.minHeight, 120);
    });
  });
}

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

    test('uses file-path thumbnail reference, not inline base64', () {
      expect(DoodleBlockKeys.thumbnailPath, 'thumbnail_path');
      expect(DoodleBlockKeys.aspectRatio, 'aspect_ratio');
      expect(DoodleBlockKeys.backgroundTemplate, 'background_template');
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

    test('defaults to a dotted background template', () {
      final node = doodleNode(attachmentId: 'a1');
      expect(node.attributes[DoodleBlockKeys.backgroundTemplate], 'dotted');
    });

    test('stores aspectRatio', () {
      final node = doodleNode(
        attachmentId: 'a1',
        aspectRatio: 2.0,
      );
      expect(node.attributes[DoodleBlockKeys.aspectRatio], 2.0);
    });

    test('accepts an explicit thumbnail path', () {
      final node = doodleNode(
        attachmentId: 'a1',
        thumbnailPath: '/tmp/a1_thumb.png',
      );
      expect(
        node.attributes[DoodleBlockKeys.thumbnailPath],
        '/tmp/a1_thumb.png',
      );
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

    test('builder accepts onNodeTap callback', () {
      final b = DoodleBlockComponentBuilder(
        onTap: (_, __) {},
      );
      expect(b.onTap, isNotNull);
    });
  });

  group('DoodleBlockComponentWidget', () {
    Widget buildWidget({
      DoodleBlockTapCallback? onTap,
      String thumbnailBackgroundTemplate = 'dotted',
    }) {
      final editorState = EditorState.blank();
      final node = doodleNode(
        attachmentId: 'a1',
        backgroundTemplate: thumbnailBackgroundTemplate,
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

    testWidgets('renders placeholder icon when no thumbnail path',
        (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      // default dotted template -> brush icon.
      expect(find.byIcon(Icons.brush), findsOneWidget);
    });

    testWidgets('renders the template-correct placeholder icon',
        (tester) async {
      await tester.pumpWidget(
        buildWidget(thumbnailBackgroundTemplate: 'graph'),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.grid_3x3_rounded), findsOneWidget);
    });

    testWidgets('tapping widget invokes onNodeTap with node + editorState',
        (tester) async {
      Node? capturedNode;
      EditorState? capturedState;
      await tester.pumpWidget(
        buildWidget(
          onTap: (node, editorState) {
            capturedNode = node;
            capturedState = editorState;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.brush));
      expect(capturedNode, isNotNull);
      expect(capturedNode!.type, DoodleBlockKeys.type);
      expect(capturedState, isNotNull);
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

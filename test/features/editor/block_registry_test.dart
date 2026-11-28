import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/editor/block_registry.dart';

void main() {
  group('BlockRegistry', () {
    test('registers core and custom block types with render & sync support',
        () {
      const expectedTypes = [
        'paragraph',
        'heading',
        'bulleted_list',
        'numbered_list',
        'todo_list',
        'quote',
        'code',
        'callout',
        'math',
        'divider',
        'image',
        'doodle',
      ];

      expect(BlockRegistry.registeredTypes, containsAll(expectedTypes));
      for (final type in expectedTypes) {
        final def = BlockRegistry.resolve(type);
        expect(def, isNotNull, reason: 'Missing block definition for $type');
        expect(def!.supportsRender, isTrue);
        expect(def.supportsSync, isTrue);
      }
      expect(BlockRegistry.resolve('unknown_block'), isNull);
    });
  });
}

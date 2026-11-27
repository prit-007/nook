import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/sync/crdt/crdt_spike.dart';

void main() {
  group('CRDT spike (Phase 2.3)', () {
    test(
        'feature flag defaults to false and spike is isolated from main sync path',
        () {
      expect(kEnableCrdtSpike, isFalse);

      final protocolFiles = Directory('lib/sync/protocol')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in protocolFiles) {
        expect(
          file.readAsStringSync().contains('crdt_spike.dart'),
          isFalse,
          reason: '${file.path} must not import crdt_spike.dart in production',
        );
      }
    });

    test('LwwElementSet converges commutatively and idempotently', () {
      final a = LwwElementSet<String>();
      final b = LwwElementSet<String>();

      a.add('block-1', timestamp: 1, replicaId: 'peer-a');
      a.add('block-2', timestamp: 2, replicaId: 'peer-a');
      b.add('block-1', timestamp: 1, replicaId: 'peer-b');
      b.remove('block-1', timestamp: 3, replicaId: 'peer-b');

      final ab = LwwElementSet<String>()
        ..mergeFrom(a)
        ..mergeFrom(b);
      final ba = LwwElementSet<String>()
        ..mergeFrom(b)
        ..mergeFrom(a);

      expect(ab.elements, equals({'block-2'}));
      expect(ba.elements, equals(ab.elements));
    });
  });
}

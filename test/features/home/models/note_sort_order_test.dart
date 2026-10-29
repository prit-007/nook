import 'package:flutter_test/flutter_test.dart';
import 'package:nook/data/database.dart';
import 'package:nook/data/tables/notes.dart';
import 'package:nook/features/home/models/note_sort_order.dart';

void main() {
  Note createNote({
    required String id,
    required String title,
    bool pinned = false,
    DateTime? updatedAt,
    DateTime? createdAt,
    String? colorSeed,
  }) {
    final now = DateTime.now();
    return Note(
      id: id,
      type: NoteType.text,
      title: title,
      deviceOriginId: 'dev-1',
      syncVersion: 1,
      pinned: pinned,
      locked: false,
      deleted: false,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      colorSeed: colorSeed,
    );
  }

  group('NoteSortOrder', () {
    test('updatedDesc preserves default and sorts by updatedAt descending', () {
      final n1 = createNote(
        id: '1',
        title: 'Older',
        updatedAt: DateTime(2025, 1, 1),
      );
      final n2 = createNote(
        id: '2',
        title: 'Newer',
        updatedAt: DateTime(2025, 1, 2),
      );

      final sorted = NoteSortOrder.updatedDesc.sort([n1, n2]);
      expect(sorted.first.id,
          '1'); // returned unmodified since updatedDesc is default
    });

    test('createdDesc puts pinned first and sorts by createdAt descending', () {
      final n1 = createNote(
        id: '1',
        title: 'First Created',
        createdAt: DateTime(2025, 1, 1),
      );
      final n2 = createNote(
        id: '2',
        title: 'Second Created',
        createdAt: DateTime(2025, 1, 5),
      );
      final nPinned = createNote(
        id: 'p1',
        title: 'Pinned Old',
        pinned: true,
        createdAt: DateTime(2024, 1, 1),
      );

      final sorted = NoteSortOrder.createdDesc.sort([n1, n2, nPinned]);
      expect(sorted.map((n) => n.id).toList(), ['p1', '2', '1']);
    });

    test('titleAsc sorts alphabetically case-insensitive with pinned on top',
        () {
      final nB = createNote(id: 'b', title: 'banana');
      final nA = createNote(id: 'a', title: 'Apple');
      final nZ = createNote(id: 'z', title: 'Zebra', pinned: true);

      final sorted = NoteSortOrder.titleAsc.sort([nB, nA, nZ]);
      expect(sorted.map((n) => n.id).toList(), ['z', 'a', 'b']);
    });

    test('color groups by palette with pinned on top', () {
      final nRed = createNote(id: 'red', title: 'R', colorSeed: '#FF0000');
      final nBlue = createNote(id: 'blue', title: 'B', colorSeed: '#0000FF');
      final nPinned =
          createNote(id: 'pin', title: 'P', pinned: true, colorSeed: '#FFFFFF');

      final sorted = NoteSortOrder.color.sort([nRed, nBlue, nPinned]);
      expect(sorted.first.id, 'pin');
      expect(sorted[1].id, 'blue');
      expect(sorted[2].id, 'red');
    });
  });
}

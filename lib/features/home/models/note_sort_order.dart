import '../../../data/database.dart';

enum NoteSortOrder {
  updatedDesc('Recently modified', 'Edited recently'),
  createdDesc('Date created', 'Newest notes first'),
  titleAsc('Title (A to Z)', 'Alphabetical order'),
  color('Color theme', 'Grouped by palette');

  const NoteSortOrder(this.label, this.subtitle);

  final String label;
  final String subtitle;

  /// Sorts a copy of [notes] according to this sort order, keeping pinned notes on top.
  List<Note> sort(List<Note> notes) {
    if (this == NoteSortOrder.updatedDesc) {
      return notes;
    }
    final list = List<Note>.from(notes);
    list.sort((a, b) {
      if (a.pinned != b.pinned) {
        return a.pinned ? -1 : 1;
      }
      switch (this) {
        case NoteSortOrder.updatedDesc:
          return b.updatedAt.compareTo(a.updatedAt);
        case NoteSortOrder.createdDesc:
          return b.createdAt.compareTo(a.createdAt);
        case NoteSortOrder.titleAsc:
          final aTitle = a.title.trim().toLowerCase();
          final bTitle = b.title.trim().toLowerCase();
          if (aTitle.isEmpty && bTitle.isEmpty) return 0;
          if (aTitle.isEmpty) return 1;
          if (bTitle.isEmpty) return -1;
          return aTitle.compareTo(bTitle);
        case NoteSortOrder.color:
          final aColor = a.colorSeed ?? '';
          final bColor = b.colorSeed ?? '';
          final cmp = aColor.compareTo(bColor);
          if (cmp != 0) return cmp;
          return b.updatedAt.compareTo(a.updatedAt);
      }
    });
    return list;
  }
}

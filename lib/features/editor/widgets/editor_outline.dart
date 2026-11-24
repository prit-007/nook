import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Entry representing a heading in the document outline.
class HeadingEntry {
  const HeadingEntry({
    required this.text,
    required this.level,
    required this.path,
  });

  final String text;
  final int level;
  final List<int> path;
}

/// Extracts all heading blocks (H1, H2, H3) from [document].
List<HeadingEntry> extractHeadings(Document document) {
  final entries = <HeadingEntry>[];

  void walk(Node node) {
    if (node.type == HeadingBlockKeys.type) {
      final level =
          (node.attributes[HeadingBlockKeys.level] as num?)?.toInt() ?? 1;
      final text = node.delta?.toPlainText().trim() ?? '';
      if (text.isNotEmpty) {
        entries.add(
          HeadingEntry(
            text: text,
            level: level,
            path: List<int>.from(node.path),
          ),
        );
      }
    }
    for (final child in node.children) {
      walk(child);
    }
  }

  for (final child in document.root.children) {
    walk(child);
  }

  return entries;
}

/// Modal bottom sheet showing the document outline.
Future<HeadingEntry?> showEditorOutlineSheet(
  BuildContext context, {
  required Document document,
}) {
  return showModalBottomSheet<HeadingEntry>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => EditorOutlineSheet(
      document: document,
      onSelect: (entry) => Navigator.pop(ctx, entry),
    ),
  );
}

/// Widget displaying the document headings hierarchy with navigation taps.
class EditorOutlineSheet extends StatelessWidget {
  const EditorOutlineSheet({
    super.key,
    required this.document,
    required this.onSelect,
  });

  final Document document;
  final ValueChanged<HeadingEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final headings = extractHeadings(document);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedMenuSquare,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                'Document Outline',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (headings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No headings found.\nUse H1, H2, or H3 to organize your note.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: headings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final entry = headings[index];
                  final indent = (entry.level - 1).clamp(0, 3) * 16.0;

                  return Padding(
                    padding: EdgeInsets.only(left: indent),
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'H${entry.level}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          entry.text,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: entry.level == 1
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => onSelect(entry),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

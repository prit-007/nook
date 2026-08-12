import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/database.dart';
import '../../../data/repositories/notebook_repository.dart';
import '../../../data/repositories/tag_repository.dart';

/// Bottom sheet for assigning a note to a notebook and tags.
///
/// Returns a [AssignmentResult] with the selected notebookId and tagIds
/// on pop, or null if cancelled.
class NoteAssignmentSheet extends ConsumerStatefulWidget {
  const NoteAssignmentSheet({
    super.key,
    required this.noteId,
    this.currentNotebookId,
  });

  final String noteId;
  final String? currentNotebookId;

  static Future<AssignmentResult?> show(
    BuildContext context, {
    required String noteId,
    String? currentNotebookId,
  }) {
    return showModalBottomSheet<AssignmentResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NoteAssignmentSheet(
        noteId: noteId,
        currentNotebookId: currentNotebookId,
      ),
    );
  }

  @override
  ConsumerState<NoteAssignmentSheet> createState() =>
      _NoteAssignmentSheetState();
}

class AssignmentResult {
  const AssignmentResult({
    required this.notebookId,
    required this.tagIds,
  });

  final String? notebookId;
  final List<String> tagIds;
}

class _NoteAssignmentSheetState extends ConsumerState<NoteAssignmentSheet> {
  String? _selectedNotebookId;
  List<String> _selectedTagIds = [];
  List<Notebook> _notebooks = [];
  List<Tag> _tags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedNotebookId = widget.currentNotebookId;
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final nbRepo = NotebookRepository(db);
    final tagRepo = TagRepository(db);

    final notebooks = await nbRepo.getAllNotebooks();
    final tags = await tagRepo.getAllTags();
    final noteTags = await tagRepo.getTagsForNote(widget.noteId);

    if (mounted) {
      setState(() {
        _notebooks = notebooks;
        _tags = tags;
        _selectedTagIds = noteTags.map((t) => t.id).toList();
        _loading = false;
      });
    }
  }

  void _selectNotebook(String? id) {
    setState(() => _selectedNotebookId = id);
    Navigator.pop(
      context,
      AssignmentResult(
        notebookId: _selectedNotebookId,
        tagIds: _selectedTagIds,
      ),
    );
  }

  void _toggleTag(String tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });
  }

  void _done() {
    Navigator.pop(
      context,
      AssignmentResult(
        notebookId: _selectedNotebookId,
        tagIds: _selectedTagIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: scrollController,
                  children: [
                    Center(
                      child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Notebook section ──
                    Text(
                      'Notebook',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_notebooks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No notebooks yet',
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    else ...[
                      // "None" option
                      _NotebookTile(
                        name: 'No notebook',
                        icon: Icons.folder_off_outlined,
                        isSelected: _selectedNotebookId == null,
                        onTap: () => _selectNotebook(null),
                      ),
                      for (final nb in _notebooks)
                        _NotebookTile(
                          name: nb.name,
                          isSelected: _selectedNotebookId == nb.id,
                          onTap: () => _selectNotebook(nb.id),
                        ),
                    ],

                    const SizedBox(height: 24),

                    // ── Tags section ──
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (_tags.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No tags yet',
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in _tags)
                            _TagChip(
                              label: tag.name,
                              colorSeed: tag.colorSeed,
                              isSelected: _selectedTagIds.contains(tag.id),
                              onTap: () => _toggleTag(tag.id),
                            ),
                        ],
                      ),

                    const SizedBox(height: 24),

                    // ── Done button ──
                    FilledButton(
                      onPressed: _done,
                      child: const Text('Done'),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _NotebookTile extends StatelessWidget {
  const _NotebookTile({
    required this.name,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon ?? Icons.book_outlined,
        color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(
        name,
        style: TextStyle(
          color: isSelected ? scheme.primary : null,
          fontWeight: isSelected ? FontWeight.w600 : null,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check, color: scheme.primary) : null,
      onTap: onTap,
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.colorSeed,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String colorSeed;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tagColor = NookColors.parseHex(colorSeed);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? tagColor.withValues(alpha: 0.2)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? tagColor : scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check, size: 16, color: tagColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? tagColor : scheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

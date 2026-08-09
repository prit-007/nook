import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/database.dart';
import '../../../data/repositories/notebook_repository.dart';
import '../../../data/repositories/tag_repository.dart';

/// Combined bottom sheet for note options: notebook, tags, and color.
class NoteOptionsSheet extends ConsumerStatefulWidget {
  const NoteOptionsSheet({
    super.key,
    required this.noteId,
    this.currentNotebookId,
    this.currentColorSeed,
    this.onNotebookChanged,
    this.onTagsChanged,
    this.onColorChanged,
  });

  final String noteId;
  final String? currentNotebookId;
  final String? currentColorSeed;
  final ValueChanged<String?>? onNotebookChanged;
  final ValueChanged<List<String>>? onTagsChanged;
  final ValueChanged<String?>? onColorChanged;

  static Future<void> show(
    BuildContext context, {
    required String noteId,
    String? currentNotebookId,
    String? currentColorSeed,
    ValueChanged<String?>? onNotebookChanged,
    ValueChanged<List<String>>? onTagsChanged,
    ValueChanged<String?>? onColorChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NoteOptionsSheet(
        noteId: noteId,
        currentNotebookId: currentNotebookId,
        currentColorSeed: currentColorSeed,
        onNotebookChanged: onNotebookChanged,
        onTagsChanged: onTagsChanged,
        onColorChanged: onColorChanged,
      ),
    );
  }

  @override
  ConsumerState<NoteOptionsSheet> createState() => _NoteOptionsSheetState();
}

class _NoteOptionsSheetState extends ConsumerState<NoteOptionsSheet> {
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
    widget.onNotebookChanged?.call(id);
  }

  void _toggleTag(String tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });
    widget.onTagsChanged?.call(_selectedTagIds);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentColor = widget.currentColorSeed != null &&
            widget.currentColorSeed!.isNotEmpty
        ? Color(
            int.parse('0xFF${widget.currentColorSeed!.replaceFirst('#', '')}'))
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.3,
      maxChildSize: 0.9,
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
                    Text(
                      'Note options',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),

                    // ── Color section ──
                    Text(
                      'Color',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ColorDot(
                          color: null,
                          isSelected: currentColor == null,
                          onTap: () => widget.onColorChanged?.call(''),
                        ),
                        for (int i = 0; i < NookColors.seeds.length; i++)
                          _ColorDot(
                            color: NookColors.seeds[i],
                            isSelected: currentColor == NookColors.seeds[i],
                            onTap: () => widget.onColorChanged?.call(
                              NookColors.seeds[i]
                                  .toARGB32()
                                  .toRadixString(16)
                                  .substring(2),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

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
                      _NotebookOption(
                        name: 'No notebook',
                        icon: Icons.folder_off_outlined,
                        isSelected: _selectedNotebookId == null,
                        onTap: () => _selectNotebook(null),
                      ),
                      for (final nb in _notebooks)
                        _NotebookOption(
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

                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? scheme.surfaceContainerHighest,
          border: Border.all(
            color: isSelected
                ? scheme.onSurface
                : scheme.outlineVariant.withValues(alpha: 0.3),
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? Icon(
                color != null ? Icons.check : Icons.close,
                size: 16,
                color: color != null
                    ? Colors.white
                    : scheme.onSurface.withValues(alpha: 0.5),
              )
            : null,
      ),
    );
  }
}

class _NotebookOption extends StatelessWidget {
  const _NotebookOption({
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
      dense: true,
      leading: Icon(
        icon ?? Icons.book_outlined,
        color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
        size: 20,
      ),
      title: Text(
        name,
        style: TextStyle(
          color: isSelected ? scheme.primary : null,
          fontWeight: isSelected ? FontWeight.w600 : null,
          fontSize: 14,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: scheme.primary, size: 20)
          : null,
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
    final tagColor = Color(int.parse('0xFF${colorSeed.replaceFirst('#', '')}'));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? tagColor.withValues(alpha: 0.2)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? tagColor : scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check, size: 14, color: tagColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
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

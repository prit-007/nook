import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/semantics.dart';
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
    this.currentlyLocked = false,
    this.onNotebookChanged,
    this.onTagsChanged,
    this.onColorChanged,
    this.onLockedChanged,
  });

  final String noteId;
  final String? currentNotebookId;
  final String? currentColorSeed;
  final bool currentlyLocked;
  final ValueChanged<String?>? onNotebookChanged;
  final ValueChanged<List<String>>? onTagsChanged;
  final ValueChanged<String?>? onColorChanged;
  final ValueChanged<bool>? onLockedChanged;

  static Future<void> show(
    BuildContext context, {
    required String noteId,
    String? currentNotebookId,
    String? currentColorSeed,
    bool currentlyLocked = false,
    ValueChanged<String?>? onNotebookChanged,
    ValueChanged<List<String>>? onTagsChanged,
    ValueChanged<String?>? onColorChanged,
    ValueChanged<bool>? onLockedChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NoteOptionsSheet(
        noteId: noteId,
        currentNotebookId: currentNotebookId,
        currentColorSeed: currentColorSeed,
        currentlyLocked: currentlyLocked,
        onNotebookChanged: onNotebookChanged,
        onTagsChanged: onTagsChanged,
        onColorChanged: onColorChanged,
        onLockedChanged: onLockedChanged,
      ),
    );
  }

  @override
  ConsumerState<NoteOptionsSheet> createState() => _NoteOptionsSheetState();
}

class _NoteOptionsSheetState extends ConsumerState<NoteOptionsSheet> {
  String? _selectedNotebookId;
  String? _selectedColorSeed;
  List<String> _selectedTagIds = [];
  List<Notebook> _notebooks = [];
  List<Tag> _tags = [];
  bool _loading = true;
  late bool _isLocked;

  // Inline notebook creation state
  bool _showingNotebookForm = false;
  final _notebookNameController = TextEditingController();
  String _newNotebookColor = '#6750A4';

  // Inline tag creation state
  bool _showingTagForm = false;
  final _tagNameController = TextEditingController();
  String _newTagColor = '#2196F3';

  @override
  void initState() {
    super.initState();
    _selectedNotebookId = widget.currentNotebookId;
    _selectedColorSeed = widget.currentColorSeed;
    _isLocked = widget.currentlyLocked;
    _load();
  }

  @override
  void dispose() {
    _notebookNameController.dispose();
    _tagNameController.dispose();
    super.dispose();
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

  Future<void> _createNotebook() async {
    final name = _notebookNameController.text.trim();
    if (name.isEmpty) return;

    final db = ref.read(databaseProvider);
    final repo = NotebookRepository(db);
    final nb = await repo.createNotebook(
      name: name,
      colorSeed: _newNotebookColor,
    );
    _notebookNameController.clear();
    setState(() {
      _showingNotebookForm = false;
      _selectedNotebookId = nb.id;
    });
    widget.onNotebookChanged?.call(nb.id);
    await _load();
  }

  Future<void> _createTag() async {
    final name = _tagNameController.text.trim();
    if (name.isEmpty) return;

    final db = ref.read(databaseProvider);
    final repo = TagRepository(db);
    final tag = await repo.createTag(
      name: name,
      colorSeed: _newTagColor,
    );
    _tagNameController.clear();
    setState(() {
      _showingTagForm = false;
      _selectedTagIds.add(tag.id);
    });
    widget.onTagsChanged?.call(_selectedTagIds);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentColor =
        _selectedColorSeed != null && _selectedColorSeed!.isNotEmpty
            ? NookColors.parseHex(_selectedColorSeed)
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
                          onTap: () {
                            setState(() => _selectedColorSeed = '');
                            widget.onColorChanged?.call('');
                          },
                        ),
                        for (int i = 0; i < NookColors.seeds.length; i++)
                          _ColorDot(
                            color: NookColors.seeds[i],
                            isSelected: currentColor == NookColors.seeds[i],
                            onTap: () {
                              final seed = NookColors.seeds[i]
                                  .toARGB32()
                                  .toRadixString(16)
                                  .substring(2);
                              setState(() => _selectedColorSeed = seed);
                              widget.onColorChanged?.call(seed);
                            },
                          ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Notebook section ──
                    Row(
                      children: [
                        Text(
                          'Notebook',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() =>
                              _showingNotebookForm = !_showingNotebookForm),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HugeIcon(
                                icon: _showingNotebookForm
                                    ? HugeIcons.strokeRoundedCancel01
                                    : HugeIcons.strokeRoundedAdd01,
                                size: 16,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showingNotebookForm
                                    ? 'Cancel'
                                    : 'New notebook',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_showingNotebookForm) ...[
                      TextField(
                        controller: _notebookNameController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Notebook name',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (_) => _createNotebook(),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final seed in NookColors.seeds)
                            GestureDetector(
                              onTap: () => setState(() => _newNotebookColor =
                                  seed
                                      .toARGB32()
                                      .toRadixString(16)
                                      .substring(2)),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: seed,
                                  border: Border.all(
                                    color: _newNotebookColor ==
                                            seed
                                                .toARGB32()
                                                .toRadixString(16)
                                                .substring(2)
                                        ? scheme.onSurface
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: _createNotebook,
                          child: const Text('Create'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_notebooks.isEmpty && !_showingNotebookForm)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No notebooks yet',
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    else if (!_showingNotebookForm) ...[
                      _NotebookOption(
                        name: 'No notebook',
                        icon: HugeIcons.strokeRoundedFolderOff,
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
                    Row(
                      children: [
                        Text(
                          'Tags',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(
                              () => _showingTagForm = !_showingTagForm),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HugeIcon(
                                icon: _showingTagForm
                                    ? HugeIcons.strokeRoundedCancel01
                                    : HugeIcons.strokeRoundedAdd01,
                                size: 16,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showingTagForm ? 'Cancel' : 'New tag',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_showingTagForm) ...[
                      TextField(
                        controller: _tagNameController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Tag name',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (_) => _createTag(),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final seed in NookColors.seeds)
                            GestureDetector(
                              onTap: () => setState(() => _newTagColor = seed
                                  .toARGB32()
                                  .toRadixString(16)
                                  .substring(2)),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: seed,
                                  border: Border.all(
                                    color: _newTagColor ==
                                            seed
                                                .toARGB32()
                                                .toRadixString(16)
                                                .substring(2)
                                        ? scheme.onSurface
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: _createTag,
                          child: const Text('Create'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_tags.isEmpty && !_showingTagForm)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No tags yet',
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    else if (!_showingTagForm)
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

                    // ── Lock section ──
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Lock note'),
                      subtitle: Text(
                        'Requires biometric to view content',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      secondary: HugeIcon(
                        icon: _isLocked
                            ? HugeIcons.strokeRoundedLock
                            : HugeIcons.strokeRoundedCircleUnlock01,
                        color: _isLocked
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      value: _isLocked,
                      onChanged: (v) {
                        setState(() => _isLocked = v);
                        widget.onLockedChanged?.call(v);
                      },
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
    final swatch = color;
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: color != null ? 'Select color' : 'No color',
        button: true,
        selected: isSelected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: swatch ?? scheme.surfaceContainerHighest,
            border: Border.all(
              color: isSelected
                  ? scheme.onSurface
                  : scheme.outlineVariant.withValues(alpha: 0.3),
              width: isSelected ? 3 : 1,
            ),
          ),
          child: isSelected
              ? HugeIcon(
                  icon: color != null
                      ? HugeIcons.strokeRoundedCheckmarkCircle01
                      : HugeIcons.strokeRoundedCancelCircle,
                  size: 18,
                  color: swatch != null
                      ? NookSemantics.contrastForeground(swatch)
                      : scheme.onSurface.withValues(alpha: 0.5),
                )
              : null,
        ),
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
  final List<List<dynamic>>? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: HugeIcon(
        icon: icon ?? HugeIcons.strokeRoundedBook01,
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
          ? HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle01,
              color: scheme.primary,
              size: 20)
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
    final tagColor = NookColors.parseHex(colorSeed);

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: label,
        button: true,
        selected: isSelected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                    size: 14,
                    color: tagColor),
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
      ),
    );
  }
}

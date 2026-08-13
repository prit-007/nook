import 'dart:ui';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/semantics.dart';
import '../../../data/database.dart';
import '../../../data/repositories/note_repository.dart';
import '../../../data/repositories/notebook_repository.dart';
import '../../../data/repositories/tag_repository.dart';

/// Contextual bottom sheet shown when long-pressing any note card.
class NoteQuickActionsSheet extends ConsumerWidget {
  const NoteQuickActionsSheet({super.key, required this.note});

  final Note note;

  static Future<void> show(BuildContext context, Note note) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteQuickActionsSheet(note: note),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final db = ref.read(databaseProvider);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            child: _QuickActionsBody(
              note: note,
              db: db,
            ),
          ),
        ),
      ),
    );
  }
}

/// Loads notebook + tag data then renders all sections.
class _QuickActionsBody extends StatefulWidget {
  const _QuickActionsBody({
    required this.note,
    required this.db,
  });

  final Note note;
  final AppDatabase db;

  @override
  State<_QuickActionsBody> createState() => _QuickActionsBodyState();
}

class _QuickActionsBodyState extends State<_QuickActionsBody> {
  late final NoteRepository _noteRepo;
  late final TagRepository _tagRepo;
  late final NotebookRepository _nbRepo;

  List<Notebook> _allNotebooks = [];
  List<Tag> _allTags = [];
  List<Tag> _noteTags = [];
  bool _loading = true;

  late Note _currentNote;

  @override
  void initState() {
    super.initState();
    _currentNote = widget.note;
    _noteRepo = NoteRepository(widget.db);
    _tagRepo = TagRepository(widget.db);
    _nbRepo = NotebookRepository(widget.db);
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _nbRepo.getAllNotebooks(),
      _tagRepo.getAllTags(),
      _tagRepo.getTagsForNote(_currentNote.id),
    ]);
    if (!mounted) return;
    setState(() {
      _allNotebooks = results[0] as List<Notebook>;
      _allTags = results[1] as List<Tag>;
      _noteTags = results[2] as List<Tag>;
      _loading = false;
    });
  }

  Future<void> _toggleTag(Tag tag) async {
    await HapticFeedback.selectionClick();
    final isAssigned = _noteTags.any((t) => t.id == tag.id);
    if (isAssigned) {
      await _tagRepo.removeTagFromNote(_currentNote.id, tag.id);
    } else {
      await _tagRepo.assignTagToNote(_currentNote.id, tag.id);
    }
    final updated = await _tagRepo.getTagsForNote(_currentNote.id);
    if (mounted) setState(() => _noteTags = updated);
  }

  Future<void> _assignNotebook(String? notebookId) async {
    await HapticFeedback.lightImpact();
    await _noteRepo.updateNote(_currentNote.id, notebookId: notebookId);
    if (mounted) {
      setState(() {
        _currentNote = _currentNote.copyWith(
          notebookId: Value(notebookId),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            _currentNote.title.isNotEmpty
                ? _currentNote.title
                : 'Untitled Note',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Quick actions ──
                    _ActionButton(
                      icon: _currentNote.pinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      label: _currentNote.pinned ? 'Unpin Note' : 'Pin Note',
                      color: _currentNote.pinned
                          ? scheme.primary
                          : scheme.onSurface,
                      onTap: () async {
                        await HapticFeedback.lightImpact();
                        await _noteRepo.updateNote(
                          _currentNote.id,
                          pinned: !_currentNote.pinned,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    _ActionButton(
                      icon: _currentNote.locked
                          ? Icons.lock_open_rounded
                          : Icons.lock_outline_rounded,
                      label: _currentNote.locked
                          ? 'Unlock Note'
                          : 'Lock with Biometrics',
                      color: scheme.onSurface,
                      onTap: () async {
                        if (!_currentNote.locked) {
                          final auth = LocalAuthentication();
                          try {
                            final ok = await auth.authenticate(
                              localizedReason: 'Authenticate to lock this note',
                              biometricOnly: true,
                              persistAcrossBackgrounding: true,
                            );
                            if (!ok) return;
                          } catch (_) {
                            return;
                          }
                        }
                        await HapticFeedback.lightImpact();
                        await _noteRepo.updateNote(
                          _currentNote.id,
                          locked: !_currentNote.locked,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // ── Color Theme ──
                    const _SectionHeader(label: 'Color Theme'),
                    const SizedBox(height: 8),
                    _ColorPickerRow(
                      currentSeed: _currentNote.colorSeed,
                      onSelected: (hex) async {
                        await _noteRepo.updateNote(
                          _currentNote.id,
                          colorSeed: hex,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Move to Notebook ──
                    const _SectionHeader(label: 'Move to Notebook'),
                    const SizedBox(height: 8),
                    _NotebookPicker(
                      notebooks: _allNotebooks,
                      currentNotebookId: _currentNote.notebookId,
                      onSelected: _assignNotebook,
                    ),

                    const SizedBox(height: 16),

                    // ── Tags ──
                    if (_allTags.isNotEmpty) ...[
                      const _SectionHeader(label: 'Tags'),
                      const SizedBox(height: 8),
                      _TagChips(
                        allTags: _allTags,
                        noteTags: _noteTags,
                        onToggle: _toggleTag,
                      ),
                    ],

                    const Divider(height: 24),

                    // ── Delete ──
                    _ActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Move to Trash',
                      color: scheme.error,
                      onTap: () async {
                        await HapticFeedback.mediumImpact();
                        await _noteRepo.softDelete(_currentNote.id);
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Section Header
// ──────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Notebook Picker
// ──────────────────────────────────────────────

class _NotebookPicker extends StatelessWidget {
  const _NotebookPicker({
    required this.notebooks,
    required this.currentNotebookId,
    required this.onSelected,
  });

  final List<Notebook> notebooks;
  final String? currentNotebookId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // "No notebook" option
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerHigh,
              border: Border.all(
                color: currentNotebookId == null
                    ? scheme.primary
                    : scheme.outlineVariant,
                width: currentNotebookId == null ? 2 : 1,
              ),
            ),
            child: currentNotebookId == null
                ? Icon(Icons.check, size: 14, color: scheme.primary)
                : Icon(Icons.folder_off_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
          ),
          title: Text(
            'No notebook',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color:
                  currentNotebookId == null ? scheme.primary : scheme.onSurface,
            ),
          ),
          onTap: () => onSelected(null),
        ),
        for (final nb in notebooks)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: _NotebookAvatar(notebook: nb),
            title: Text(
              nb.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: currentNotebookId == nb.id
                    ? scheme.primary
                    : scheme.onSurface,
              ),
            ),
            trailing: currentNotebookId == nb.id
                ? Icon(Icons.check_circle_rounded,
                    size: 18, color: scheme.primary)
                : null,
            onTap: () => onSelected(nb.id),
          ),
      ],
    );
  }
}

class _NotebookAvatar extends StatelessWidget {
  const _NotebookAvatar({required this.notebook});

  final Notebook notebook;

  @override
  Widget build(BuildContext context) {
    final seed = NookColors.parseHex(notebook.colorSeed);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ColorScheme.fromSeed(seedColor: seed).primaryContainer,
      ),
      child: Icon(
        Icons.book_rounded,
        size: 16,
        color: ColorScheme.fromSeed(seedColor: seed).onPrimaryContainer,
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Tag Chips
// ──────────────────────────────────────────────

class _TagChips extends StatelessWidget {
  const _TagChips({
    required this.allTags,
    required this.noteTags,
    required this.onToggle,
  });

  final List<Tag> allTags;
  final List<Tag> noteTags;
  final ValueChanged<Tag> onToggle;

  @override
  Widget build(BuildContext context) {
    final noteTagIds = noteTags.map((t) => t.id).toSet();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in allTags)
          _TagChip(
            tag: tag,
            isSelected: noteTagIds.contains(tag.id),
            onTap: () => onToggle(tag),
          ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  final Tag tag;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tagColor = NookColors.parseHex(tag.colorSeed);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? tagColor.withValues(alpha: 0.15)
              : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? tagColor
                : scheme.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tagColor,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              tag.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? tagColor : scheme.onSurface,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_rounded, size: 14, color: tagColor),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  Action Button
// ──────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ──────────────────────────────────────────────
//  Color Picker Row
// ──────────────────────────────────────────────

class _ColorPickerRow extends StatelessWidget {
  const _ColorPickerRow({
    required this.currentSeed,
    required this.onSelected,
  });

  final String? currentSeed;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ColorChoice(
            color: null,
            isSelected: currentSeed == null || currentSeed!.isEmpty,
            onTap: () => onSelected(null),
          ),
          for (int i = 0; i < _seedColors.length; i++) ...[
            const SizedBox(width: 8),
            _ColorChoice(
              color: _seedColors[i],
              isSelected: currentSeed ==
                  _seedColors[i].toARGB32().toRadixString(16).substring(2),
              onTap: () {
                final hex =
                    _seedColors[i].toARGB32().toRadixString(16).substring(2);
                onSelected(hex);
              },
            ),
          ],
        ],
      ),
    );
  }

  static const _seedColors = [
    Color(0xFF6750A4),
    Color(0xFF006A6A),
    Color(0xFFBF4A3F),
    Color(0xFF5A6340),
    Color(0xFF7D5700),
    Color(0xFF984061),
    Color(0xFF0061A4),
    Color(0xFF4A5568),
    Color(0xFF4355B9),
    Color(0xFF006D3B),
    Color(0xFF9C4400),
    Color(0xFF7B4F9A),
  ];
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.isSelected,
    required this.onTap,
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? scheme.surfaceContainerHigh,
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? Icon(Icons.check,
                size: 16,
                color: swatch != null
                    ? NookSemantics.contrastForeground(swatch)
                    : scheme.primary)
            : null,
      ),
    );
  }
}

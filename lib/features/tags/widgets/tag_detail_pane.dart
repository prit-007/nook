import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/selection_providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/database.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../home/widgets/note_card.dart';

/// Right-hand pane of the tags master-detail layout on tablets.
///
/// Shows the notes of the tag selected in the left-hand pill list. Renders no
/// Scaffold or AppBar — it is embedded beside the tags list.
class TagDetailPane extends ConsumerWidget {
  const TagDetailPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagId = ref.watch(selectedTagIdProvider);
    final scheme = Theme.of(context).colorScheme;

    if (tagId == null) {
      return ColoredBox(
        color: scheme.surfaceContainerLowest,
        child: const Center(
          child: EmptyState(
            icon: LucideIcons.tags,
            title: 'Select a tag',
            subtitle: 'Choose a tag to browse its notes.',
            animate: false,
          ),
        ),
      );
    }

    return _TagNotesPane(tagId: tagId);
  }
}

class _TagNotesPane extends ConsumerStatefulWidget {
  const _TagNotesPane({required this.tagId});

  final String tagId;

  @override
  ConsumerState<_TagNotesPane> createState() => _TagNotesPaneState();
}

class _TagNotesPaneState extends ConsumerState<_TagNotesPane> {
  String _tagName = '';
  Color? _tagColor;
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _TagNotesPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tagId != widget.tagId) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final repo = TagRepository(ref.read(databaseProvider));
    final tag = await repo.getTagById(widget.tagId);
    final notes = await repo.getNotesForTag(widget.tagId);
    if (!mounted) return;
    setState(() {
      _tagName = tag?.name ?? '';
      _tagColor = tag == null ? null : NookColors.parseHex(tag.colorSeed);
      _notes = notes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _tagColor ?? scheme.primary;

    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Icon(LucideIcons.tag, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _tagName.isEmpty ? 'Tag' : _tagName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: accent,
                    ),
                  ),
                ),
                Text(
                  '${_notes.length} note${_notes.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty
                    ? const EmptyState(
                        icon: LucideIcons.fileText,
                        title: 'No notes found',
                        subtitle: 'Tag your notes to see them here',
                        animate: false,
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _notes.length,
                        itemBuilder: (context, index) => NoteCard(
                          note: _notes[index],
                          onTap: () =>
                              context.push('/note/${_notes[index].id}'),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

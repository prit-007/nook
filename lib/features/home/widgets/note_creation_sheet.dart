import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/note_type_preset_provider.dart';
import '../../../core/theme/nook_tokens.dart';
import '../../../core/widgets/paper_texture_painter.dart';
import '../../../data/database.dart';
import '../../../data/repositories/template_repository.dart';
import '../../../data/tables/notes.dart';
import 'note_type_morph_selector.dart';

/// Result emitted when creating a note from [NoteCreationSheet].
class NoteCreationChoice {
  const NoteCreationChoice({
    required this.type,
    required this.preset,
    this.templateId,
  });

  final NoteType type;
  final NoteTypePreset preset;
  final String? templateId;
}

/// Unified New Note sheet combining [NoteTypeMorphSelector], per-type
/// [NoteTypePreset] customization, and [TemplateRepository] templates.
class NoteCreationSheet extends ConsumerStatefulWidget {
  const NoteCreationSheet({
    super.key,
    required this.onCreate,
    this.initialType = NoteType.text,
  });

  final ValueChanged<NoteCreationChoice> onCreate;
  final NoteType initialType;

  @override
  ConsumerState<NoteCreationSheet> createState() => _NoteCreationSheetState();
}

class _NoteCreationSheetState extends ConsumerState<NoteCreationSheet> {
  late NoteType _selectedType = widget.initialType;
  List<Template> _templates = const [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final db = ref.read(databaseProvider);
    final all = await TemplateRepository(db).all();
    if (!mounted) return;
    setState(() => _templates = all);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = ref.watch(noteTypePresetProvider);
    final preset = store.forType(_selectedType);

    return Padding(
      padding: const EdgeInsets.all(NookTokens.kSpacingLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New Note',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: NookTokens.kSpacingMd),
          NoteTypeMorphSelector(
            selected: _selectedType,
            onSelected: (type) => setState(() => _selectedType = type),
          ),
          const SizedBox(height: NookTokens.kSpacingMd),
          Wrap(
            spacing: NookTokens.kSpacingSm,
            children: [
              for (final pattern in PaperPattern.values)
                ChoiceChip(
                  label: Text(pattern.name),
                  selected: preset.paperPattern == pattern,
                  onSelected: (_) {
                    store.updatePreset(
                      NoteTypePreset(
                        type: _selectedType,
                        paperPattern: pattern,
                        colorSeed: preset.colorSeed,
                        fontStyle: preset.fontStyle,
                      ),
                    );
                  },
                ),
            ],
          ),
          if (_templates.isNotEmpty) ...[
            const SizedBox(height: NookTokens.kSpacingMd),
            Text(
              'Templates',
              style: TextStyle(
                fontSize: NookTokens.kFontFloor,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: NookTokens.kSpacingXs),
            Wrap(
              spacing: NookTokens.kSpacingSm,
              runSpacing: NookTokens.kSpacingXs,
              children: [
                for (final t in _templates)
                  ActionChip(
                    avatar: HugeIcon(
                      icon: HugeIcons.strokeRoundedBook01,
                      size: 14,
                      color: scheme.primary,
                    ),
                    label: Text(t.name),
                    onPressed: () {
                      widget.onCreate(
                        NoteCreationChoice(
                          type: _selectedType,
                          preset: store.forType(_selectedType),
                          templateId: t.id,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: NookTokens.kSpacingLg),
          FilledButton(
            onPressed: () {
              widget.onCreate(
                NoteCreationChoice(
                  type: _selectedType,
                  preset: preset,
                ),
              );
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

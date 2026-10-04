import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import 'dart:async';

import '../../core/providers/database_provider.dart';
import '../../data/database.dart';
import '../../data/repositories/template_repository.dart';

/// Bottom sheet to pick a note template and create a note from it.
Future<void> showTemplatePickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _TemplatePickerSheet(),
  );
}

class _TemplatePickerSheet extends ConsumerStatefulWidget {
  const _TemplatePickerSheet();

  @override
  ConsumerState<_TemplatePickerSheet> createState() =>
      _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends ConsumerState<_TemplatePickerSheet> {
  List<Template> _templates = [];
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final repo = TemplateRepository(db);
    await repo.seedBuiltinsIfEmpty();
    final templates = await repo.all();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _loading = false;
    });
  }

  Future<void> _createFrom(Template template) async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final db = ref.read(databaseProvider);
      final note =
          await TemplateRepository(db).createNoteFromTemplate(template.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      unawaited(context.push('/note/${note.id}'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create note: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start from template',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Creates a new note — templates are never consumed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _templates.length,
                    itemBuilder: (context, index) {
                      final t = _templates[index];
                      return ListTile(
                        leading: HugeIcon(
                          icon: HugeIcons.strokeRoundedBook01,
                          size: 20,
                          color: scheme.primary,
                        ),
                        title: Text(t.name),
                        subtitle: Text(
                          (t.plainText ?? '').trim().isEmpty
                              ? 'Empty template'
                              : (t.plainText!).trim().split('\n').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _creating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowRight01,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                        onTap: _creating ? null : () => _createFrom(t),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Settings screen section entry (optional helper for storage/about).
class TemplatesEmptyState extends StatelessWidget {
  const TemplatesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

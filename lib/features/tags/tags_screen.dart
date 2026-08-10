import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/database_provider.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/database.dart';
import '../../data/repositories/tag_repository.dart';

/// Tags list screen — tag chips with CRUD.
class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  List<Tag> _tags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = TagRepository(ref.read(databaseProvider));
    final results = await repo.getAllTags();
    setState(() {
      _tags = results;
      _loading = false;
    });
  }

  void _showCreateSheet() {
    final nameController = TextEditingController();
    String selectedColor = '#2196F3';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Tag',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. important, todo',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                '#2196F3',
                '#4CAF50',
                '#FF9800',
                '#E91E63',
                '#9C27B0',
                '#00BCD4',
              ].map((c) {
                final color = Color(
                  int.parse('FF${c.replaceFirst('#', '')}', radix: 16),
                );
                return GestureDetector(
                  onTap: () => setState(() => selectedColor = c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedColor == c
                            ? Theme.of(ctx).colorScheme.onSurface
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    final repo = TagRepository(ref.read(databaseProvider));
                    await repo.createTag(
                      name: nameController.text.trim(),
                      colorSeed: selectedColor,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Tag tag) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tag'),
        content: Text('Delete "${tag.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final repo = TagRepository(ref.read(databaseProvider));
              await repo.deleteTag(tag.id);
              if (ctx.mounted) Navigator.pop(ctx);
              await _load();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tags.isEmpty
              ? const EmptyState(
                  icon: Icons.label_outlined,
                  title: 'No tags',
                  subtitle: 'Tap + to create one',
                  animate: false,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _tags.map((tag) {
                        final tagColor = Color(
                          int.parse(
                            'FF${tag.colorSeed.replaceFirst('#', '')}',
                            radix: 16,
                          ),
                        );
                        return GestureDetector(
                          onTap: () => context.push('/tags/${tag.id}'),
                          onLongPress: () => _showDeleteDialog(tag),
                          child: Chip(
                            label: Text(tag.name),
                            backgroundColor: tagColor.withValues(alpha: 0.15),
                            labelStyle: TextStyle(color: tagColor),
                            side: BorderSide(
                                color: tagColor.withValues(alpha: 0.3)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}

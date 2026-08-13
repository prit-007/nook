import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/adaptive_breakpoints.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/selection_providers.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/parallax_card.dart';
import '../../data/database.dart';
import '../../data/repositories/notebook_repository.dart';
import 'widgets/notebook_card.dart';
import 'widgets/notebook_detail_pane.dart';

/// Notebooks list screen — grid of notebook cards with CRUD.
class NotebooksScreen extends ConsumerStatefulWidget {
  const NotebooksScreen({super.key});

  @override
  ConsumerState<NotebooksScreen> createState() => _NotebooksScreenState();
}

class _NotebooksScreenState extends ConsumerState<NotebooksScreen> {
  List<Notebook> _notebooks = [];
  Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = NotebookRepository(ref.read(databaseProvider));
    final results = await repo.getAllNotebooks();
    final counts = await repo.countNotesForAllNotebooks();
    if (!mounted) return;
    setState(() {
      _notebooks = results;
      _counts = counts;
      _loading = false;
    });
  }

  void _showCreateSheet() {
    final nameController = TextEditingController();
    String selectedColor = '#FF5722';

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
              'Create Notebook',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Work, Personal',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                '#FF5722',
                '#2196F3',
                '#4CAF50',
                '#9C27B0',
                '#FF9800',
                '#E91E63',
              ].map((c) {
                final color = Color(
                  int.parse('FF${c.replaceFirst('#', '')}', radix: 16),
                );
                return Semantics(
                  label: 'Color option',
                  button: true,
                  child: GestureDetector(
                    onTap: () => setState(() => selectedColor = c),
                    child: Container(
                      width: 48,
                      height: 48,
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
                    final repo = NotebookRepository(
                      ref.read(databaseProvider),
                    );
                    await repo.createNotebook(
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

  void _showDeleteDialog(Notebook notebook) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Notebook'),
        content: Text(
          'Delete "${notebook.name}"? Notes inside will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final repo = NotebookRepository(ref.read(databaseProvider));
              await repo.deleteNotebook(notebook.id);
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
    final scheme = Theme.of(context).colorScheme;
    final isDualPane = AdaptiveBreakpoints.supportsDualPane(context);

    final grid = _notebooksGrid(scheme, isDualPane);

    return Scaffold(
      appBar: AppBar(title: const Text('Notebooks')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : isDualPane
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(flex: 3, child: grid),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                    const Flexible(flex: 2, child: NotebookDetailPane()),
                  ],
                )
              : grid,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 114),
        child: FloatingActionButton(
          onPressed: _showCreateSheet,
          tooltip: 'Create notebook',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _notebooksGrid(ColorScheme scheme, bool isDualPane) {
    if (_notebooks.isEmpty) {
      return const EmptyState(
        icon: Icons.book_outlined,
        title: 'No notebooks',
        subtitle: 'Tap + to create one',
        animate: false,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.62,
        ),
        itemCount: _notebooks.length,
        itemBuilder: (context, index) {
          final nb = _notebooks[index];
          final card = GestureDetector(
            onTap: () {
              if (isDualPane) {
                ref.read(selectedNotebookIdProvider.notifier).state = nb.id;
                return;
              }
              context.push('/notebooks/${nb.id}');
            },
            onLongPress: () => _showDeleteDialog(nb),
            child: NotebookCard(
              notebook: nb,
              noteCount: _counts[nb.id] ?? 0,
            ),
          );
          if (MediaQuery.disableAnimationsOf(context)) return card;
          return ParallaxCard(child: card);
        },
      ),
    );
  }
}

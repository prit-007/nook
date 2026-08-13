import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/adaptive_breakpoints.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/selection_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/parallax_card.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../data/database.dart';
import '../../data/repositories/notebook_repository.dart';
import 'widgets/notebook_card.dart';
import 'widgets/notebook_detail_pane.dart';

/// Notebooks list screen — grid of notebook cards with CRUD.
class NotebooksScreen extends ConsumerStatefulWidget {
  const NotebooksScreen({super.key, this.embedded = false});

  final bool embedded;

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
    HapticFeedback.mediumImpact();
    final nameController = TextEditingController();
    Color selectedColor = NookColors.defaultSeed;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final scheme = Theme.of(context).colorScheme;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(32),
                    ),
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
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Create Notebook',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Work, Personal',
                            filled: true,
                            fillColor: scheme.surface.withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'COLOR THEME',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final seed in NookColors.seeds)
                              _SeedColorDot(
                                color: seed,
                                isSelected: seed == selectedColor,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setModalState(() => selectedColor = seed);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () async {
                                  if (nameController.text.trim().isEmpty) {
                                    return;
                                  }
                                  unawaited(HapticFeedback.lightImpact());
                                  final repo = NotebookRepository(
                                    ref.read(databaseProvider),
                                  );
                                  await repo.createNotebook(
                                    name: nameController.text.trim(),
                                    colorSeed: _hexFromColor(selectedColor),
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _load();
                                },
                                child: const Text(
                                  'Save',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
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
      appBar: widget.embedded ? null : AppBar(title: const Text('Notebooks')),
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
        padding: EdgeInsets.only(
          bottom: DockSafeArea.bottomOf(context) + 16,
        ),
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
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          DockSafeArea.bottomOf(context) + 72,
        ),
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

/// Formats a [Color] as the app's stored `#RRGGBB` seed string.
String _hexFromColor(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

/// Tappable color swatch used by the notebook create sheet.
class _SeedColorDot extends StatelessWidget {
  const _SeedColorDot({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? scheme.onSurface : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

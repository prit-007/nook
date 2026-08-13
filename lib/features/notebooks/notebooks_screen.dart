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
import '../../core/widgets/dock_safe_area.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/parallax_card.dart';
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
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        const SizedBox(height: 24),
                        Text(
                          'New Collection',
                          style: TextStyle(
                            fontFamily: 'Playfair Display',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: scheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Architectural Studies, Journal',
                            hintStyle: TextStyle(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            filled: true,
                            fillColor: scheme.surface.withValues(alpha: 0.6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'ACCENT PALETTE',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 14),
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
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: selectedColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
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
                                  'Create',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700,
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
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Delete Notebook',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${notebook.name}"? Notes inside '
          'will remain safely intact.',
          style: TextStyle(
            fontFamily: 'Inter',
            color: scheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
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
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                'Collections',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: scheme.onSurface,
                ),
              ),
              centerTitle: false,
            ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : isDualPane
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(flex: 3, child: grid),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.15),
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
        child: FloatingActionButton.extended(
          // Unique hero tag: both NotebooksScreen and TagsScreen stay alive in
          // the CollectionsScreen IndexedStack, so sharing the default FAB hero
          // tag would throw "multiple heroes with the same tag" every build.
          heroTag: 'fab-notebooks',
          onPressed: _showCreateSheet,
          tooltip: 'Create notebook',
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'New',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _notebooksGrid(ColorScheme scheme, bool isDualPane) {
    if (_notebooks.isEmpty) {
      return const EmptyState(
        icon: Icons.book_outlined,
        title: 'No collections yet',
        subtitle: 'Tap + New to create your first notebook.',
        animate: false,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: scheme.primary,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          DockSafeArea.bottomOf(context) + 80,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 0.65, // Elegant portrait aspect ratio
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

String _hexFromColor(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 20,
              )
            : null,
      ),
    );
  }
}

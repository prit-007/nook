import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hugeicons/hugeicons.dart';
import '../../core/adaptive_breakpoints.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/selection_providers.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/parallax_card.dart';
import '../../data/database.dart';
import '../../data/repositories/notebook_repository.dart';
import 'widgets/notebook_card.dart';
import 'widgets/notebook_detail_pane.dart';

/// Layout view mode for the notebooks screen.
enum NotebookViewMode { grid, list }

/// Notebooks list screen — grid or list of notebook cards with CRUD.
class NotebooksScreen extends ConsumerStatefulWidget {
  const NotebooksScreen({
    super.key,
    this.embedded = false,
    this.onCreateRegistered,
    this.viewMode,
  });

  final bool embedded;

  /// Optional view mode override (e.g. controlled by [NotebooksScreen]).
  final NotebookViewMode? viewMode;

  /// When set, the screen registers its create action with this callback so
  /// an external widget (e.g. [NotebooksScreen]) can trigger creation.
  final void Function(VoidCallback onShowCreate)? onCreateRegistered;

  @override
  ConsumerState<NotebooksScreen> createState() => _NotebooksScreenState();
}

class _NotebooksScreenState extends ConsumerState<NotebooksScreen>
    with AutomaticKeepAliveClientMixin {
  List<Notebook> _notebooks = [];
  Map<String, int> _counts = {};
  bool _loading = true;
  NotebookViewMode _internalViewMode = NotebookViewMode.grid;

  NotebookViewMode get _effectiveViewMode =>
      widget.viewMode ?? _internalViewMode;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.onCreateRegistered?.call(showCreateSheet);
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

  void showCreateSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateNotebookSheet(onCreated: _load),
    );
  }

  void _showDeleteDialog(Notebook notebook) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Move Notebook to Bin?',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        content: Text(
          'Do you want to move the notes in this notebook to the bin too?',
          style: TextStyle(
            fontFamily: 'Inter',
            color: scheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.errorContainer,
              foregroundColor: scheme.onErrorContainer,
            ),
            onPressed: () async {
              final repo = NotebookRepository(ref.read(databaseProvider));
              await repo.softDelete(notebook.id);
              if (ctx.mounted) Navigator.pop(ctx);
              await _load();
            },
            child: const Text('Notebook only'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () async {
              final repo = NotebookRepository(ref.read(databaseProvider));
              await repo.softDeleteNotebookAndNotes(notebook.id);
              if (ctx.mounted) Navigator.pop(ctx);
              await _load();
            },
            child: const Text('Notes too'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final isDualPane = AdaptiveBreakpoints.supportsDualPane(context);

    final content = _effectiveViewMode == NotebookViewMode.grid
        ? _notebooksGrid(scheme, isDualPane)
        : _notebooksList(scheme, isDualPane);

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                'Notebooks',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: scheme.onSurface,
                ),
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedDelete01,
                    size: 22,
                  ),
                  tooltip: 'Bin / Trash',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push('/trash');
                  },
                ),
                IconButton(
                  icon: HugeIcon(
                    icon: _effectiveViewMode == NotebookViewMode.grid
                        ? HugeIcons.strokeRoundedListView
                        : HugeIcons.strokeRoundedGridView,
                    size: 22,
                  ),
                  tooltip: _effectiveViewMode == NotebookViewMode.grid
                      ? 'Switch to list view'
                      : 'Switch to grid view',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _internalViewMode =
                          _effectiveViewMode == NotebookViewMode.grid
                              ? NotebookViewMode.list
                              : NotebookViewMode.grid;
                    });
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : isDualPane
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      flex: 3,
                      child: Container(
                        color:
                            scheme.surfaceContainerLow.withValues(alpha: 0.3),
                        child: content,
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.15),
                    ),
                    const Flexible(flex: 2, child: NotebookDetailPane()),
                  ],
                )
              : content,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: widget.embedded
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: DockSafeArea.bottomOf(context) + 16,
              ),
              child: FloatingActionButton.extended(
                // Unique hero tag: both NotebooksScreen and TagsScreen stay alive in
                // the NotebooksScreen IndexedStack, so sharing the default FAB hero
                // tag would throw "multiple heroes with the same tag" every build.
                heroTag: 'fab-notebooks',
                onPressed: showCreateSheet,
                tooltip: 'Create notebook',
                icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedAdd01,
                    size: 24,
                    color: scheme.onPrimary),
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

  Widget _notebooksList(ColorScheme scheme, bool isDualPane) {
    if (_notebooks.isEmpty) {
      return const EmptyState(
        icon: HugeIcons.strokeRoundedBook01,
        title: 'No notebooks yet',
        subtitle: 'Tap + New to create your first notebook.',
        animate: false,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: scheme.primary,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          DockSafeArea.bottomOf(context) + 80,
        ),
        itemCount: _notebooks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final nb = _notebooks[index];
          final noteCount = _counts[nb.id] ?? 0;
          final seed = NookColors.parseHex(nb.colorSeed);
          final hasParent = nb.name.contains('/');
          final parent = hasParent
              ? nb.name
                  .split('/')
                  .sublist(0, nb.name.split('/').length - 1)
                  .map((s) => s.trim())
                  .join(' › ')
              : null;
          final displayName =
              hasParent ? nb.name.split('/').last.trim() : nb.name;

          return Material(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                if (isDualPane) {
                  ref.read(selectedNotebookIdProvider.notifier).state = nb.id;
                  return;
                }
                context.push('/notebooks/${nb.id}');
              },
              onLongPress: () => _showDeleteDialog(nb),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: seed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: seed.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (parent != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                parent,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurfaceVariant,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          Text(
                            displayName,
                            style: TextStyle(
                              fontFamily: 'Playfair Display',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$noteCount ${noteCount == 1 ? 'entry' : 'entries'}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 16,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _notebooksGrid(ColorScheme scheme, bool isDualPane) {
    if (_notebooks.isEmpty) {
      return const EmptyState(
        icon: HugeIcons.strokeRoundedBook01,
        title: 'No notebooks yet',
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
        duration: AppMotion.medium1,
        curve: AppMotion.emphasizedDecelerate,
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
            ? HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                color: color.computeLuminance() > 0.5
                    ? Colors.black87
                    : Colors.white,
                size: 20,
              )
            : null,
      ),
    );
  }
}

/// Bottom sheet for creating a new notebook.
///
/// Owns its [TextEditingController] (disposed with the sheet) so the field's
/// lifetime matches the sheet's route — it is neither leaked nor disposed
/// while the sheet's exit transition is still animating.
class _CreateNotebookSheet extends ConsumerStatefulWidget {
  const _CreateNotebookSheet({required this.onCreated});

  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateNotebookSheet> createState() =>
      _CreateNotebookSheetState();
}

class _CreateNotebookSheetState extends ConsumerState<_CreateNotebookSheet> {
  final _nameController = TextEditingController();
  Color _selectedColor = NookColors.defaultSeed;
  List<Notebook> _existingNotebooks = [];
  Notebook? _selectedParent;

  @override
  void initState() {
    super.initState();
    _loadExistingNotebooks();
  }

  Future<void> _loadExistingNotebooks() async {
    final repo = NotebookRepository(ref.read(databaseProvider));
    final notebooks = await repo.getAllNotebooks();
    if (mounted) {
      setState(() => _existingNotebooks = notebooks);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final rawName = _nameController.text.trim();
    if (rawName.isEmpty) return;
    unawaited(HapticFeedback.lightImpact());
    final fullName = _selectedParent != null
        ? '${_selectedParent!.name} / $rawName'
        : rawName;
    final repo = NotebookRepository(ref.read(databaseProvider));
    await repo.createNotebook(
      name: fullName,
      colorSeed: _hexFromColor(_selectedColor),
    );
    if (mounted) Navigator.pop(context);
    widget.onCreated();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.75),
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
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'New Notebook',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: scheme.onSurface,
                  ),
                ),
                if (_existingNotebooks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Parent notebook (optional)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedParent?.id,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: scheme.surface.withValues(alpha: 0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'None (top level)',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      for (final nb in _existingNotebooks)
                        DropdownMenuItem<String?>(
                          value: nb.id,
                          child: Text(
                            nb.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      setState(() {
                        _selectedParent = id == null
                            ? null
                            : _existingNotebooks.firstWhere((n) => n.id == id);
                      });
                    },
                  ),
                ],
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: _selectedParent != null
                        ? 'e.g. Projects, Architecture'
                        : 'e.g. Architectural Studies, Journal',
                    hintStyle: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
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
                  'Accent palette',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: scheme.onSurfaceVariant,
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
                        isSelected: seed == _selectedColor,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedColor = seed);
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
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
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
                          backgroundColor: _selectedColor,
                          foregroundColor: scheme.onPrimaryContainer,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _create,
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
    );
  }
}

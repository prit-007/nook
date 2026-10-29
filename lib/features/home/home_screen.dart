import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/adaptive_breakpoints.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/selection_providers.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../core/widgets/floating_undo_snackbar.dart';
import '../../core/widgets/parallax_card.dart';
import '../../data/database.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/tables/notes.dart';
import '../templates/template_picker_sheet.dart';
import '../updates/widgets/update_banner.dart';
import 'models/note_sort_order.dart';
import 'providers/notes_list_provider.dart';
import 'providers/note_card_metadata_provider.dart';
import 'widgets/batch_action_bar.dart';
import 'widgets/batch_action_sheets.dart';
import 'widgets/empty_home.dart';
import 'widgets/filter_pill_bar.dart';
import 'widgets/morphing_editorial_fab.dart';
import 'widgets/note_banner_card.dart';
import 'widgets/note_doodle_card.dart';
import 'widgets/note_minimal_card.dart';
import 'widgets/note_preview_pane.dart';
import 'widgets/note_sort_sheet.dart';
import 'widgets/pull_to_search.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.animate = true});

  final bool animate;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  NoteType? _selectedType;
  NoteSortOrder _sortOrder = NoteSortOrder.updatedDesc;
  bool _isSelectionMode = false;
  final Set<String> _selectedNoteIds = {};

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning thoughts.';
    if (hour < 17) return 'Afternoon flow.';
    if (hour < 22) return 'Evening reflections.';
    return 'Late night ideas.';
  }

  void _toggleSelection(String noteId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedNoteIds.contains(noteId)) {
        _selectedNoteIds.remove(noteId);
      } else {
        _selectedNoteIds.add(noteId);
      }
    });
  }

  void _enterSelectionMode([String? initialNoteId]) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      if (initialNoteId != null) {
        _selectedNoteIds.add(initialNoteId);
      }
    });
  }

  void _exitSelectionMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSelectionMode = false;
      _selectedNoteIds.clear();
    });
  }

  Future<void> _batchTogglePin(List<Note> allNotes) async {
    final selectedNotes =
        allNotes.where((n) => _selectedNoteIds.contains(n.id)).toList();
    final allPinned =
        selectedNotes.isNotEmpty && selectedNotes.every((n) => n.pinned);
    final newPinned = !allPinned;
    final db = ref.read(databaseProvider);
    final repo = NoteRepository(db);
    for (final id in _selectedNoteIds) {
      await repo.updateNote(id, pinned: newPinned);
    }
    _exitSelectionMode();
  }

  Future<void> _batchMoveToNotebook() async {
    final db = ref.read(databaseProvider);
    final notebookId = await showBatchNotebookPicker(context, db: db);
    if (notebookId == null || !mounted) return;
    final repo = NoteRepository(db);
    final targetId = notebookId.isEmpty ? null : notebookId;
    for (final id in _selectedNoteIds) {
      await repo.updateNote(id, notebookId: targetId);
    }
    _exitSelectionMode();
  }

  Future<void> _batchAddTag() async {
    final db = ref.read(databaseProvider);
    final tag = await showBatchTagPicker(context, db: db);
    if (tag == null || !mounted) return;
    final tagRepo = TagRepository(db);
    for (final id in _selectedNoteIds) {
      await tagRepo.assignTagToNote(id, tag.id);
    }
    _exitSelectionMode();
  }

  Future<void> _batchDelete() async {
    final ids = _selectedNoteIds.toList();
    final count = ids.length;
    final db = ref.read(databaseProvider);
    final repo = NoteRepository(db);
    for (final id in ids) {
      await repo.softDelete(id);
    }
    _exitSelectionMode();
    if (mounted) {
      showUndoSnackBar(
        context,
        message: 'Moved $count ${count == 1 ? 'note' : 'notes'} to Bin',
        onUndo: () async {
          for (final id in ids) {
            await repo.restore(id);
          }
        },
      );
    }
  }

  List<Note> _applyFilters(List<Note> notes) {
    if (_selectedType == null) return notes;
    return notes.where((n) => n.type == _selectedType).toList();
  }

  Map<NoteType?, int> _computeCounts(List<Note> notes) {
    final map = <NoteType?, int>{null: notes.length};
    for (final type in NoteType.values) {
      map[type] = notes.where((n) => n.type == type).length;
    }
    return map;
  }

  void _openNote(String noteId) {
    HapticFeedback.selectionClick();
    if (AdaptiveBreakpoints.supportsDualPane(context)) {
      ref.read(selectedNoteIdProvider.notifier).state = noteId;
      return;
    }
    context.push('/note/$noteId');
  }

  bool _animationsAllowed(BuildContext context) {
    if (!widget.animate) return false;
    final preferredOff = ref.read(themePreferenceProvider).reduceMotion;
    return !preferredOff && !MediaQuery.disableAnimationsOf(context);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final notesAsync = ref.watch(notesListProvider);
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final sizeClass = _windowSizeClass(width);
    final isWide = sizeClass != WindowSizeClass.compact;
    final isDualPane = AdaptiveBreakpoints.supportsDualPane(context);
    final animate = _animationsAllowed(context);

    // The shell already offsets the body by the full dock height (72 + 24 +
    // bottom inset), so the FAB only needs a small gap above the body's bottom
    // edge — no need to re-add the dock height here.
    final safeBottom = DockSafeArea.bottomOf(context) + 16;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: PopScope(
        canPop: !_isSelectionMode,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _isSelectionMode) {
            _exitSelectionMode();
          }
        },
        child: Stack(
          children: [
            notesAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: scheme.primary),
              ),
              error: (e, _) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load your vault.\nPlease try again later.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (notes) {
                final sortedNotes = _sortOrder.sort(notes);
                final filtered = _applyFilters(sortedNotes);
                final counts = _computeCounts(notes);
                final grid = _buildHomeScroller(
                  context,
                  notes: notes,
                  filtered: filtered,
                  counts: counts,
                  isWide: isWide,
                  animate: animate,
                  safeBottom: safeBottom,
                );

                if (isDualPane) {
                  // Responsive split ratio by window size class.
                  final leftFlex = sizeClass == WindowSizeClass.medium ? 2 : 3;
                  final rightFlex = sizeClass == WindowSizeClass.medium ? 1 : 2;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        flex: leftFlex,
                        child: Container(
                          color:
                              scheme.surfaceContainerLow.withValues(alpha: 0.3),
                          child: grid,
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                      Flexible(flex: rightFlex, child: const NotePreviewPane()),
                    ],
                  );
                }
                return grid;
              },
            ),
            if (_isSelectionMode)
              Positioned(
                left: 20,
                right: 20,
                bottom: safeBottom,
                child: BatchActionBar(
                  selectedCount: _selectedNoteIds.length,
                  allPinned: _selectedNoteIds.isNotEmpty &&
                      (notesAsync.value ?? [])
                          .where((n) => _selectedNoteIds.contains(n.id))
                          .every((n) => n.pinned),
                  onTogglePin: () => _batchTogglePin(notesAsync.value ?? []),
                  onMoveToNotebook: _batchMoveToNotebook,
                  onAddTag: _batchAddTag,
                  onDelete: _batchDelete,
                  onClose: _exitSelectionMode,
                ),
              )
            else
              MorphingEditorialFab(
                mobileBottomOffset: safeBottom,
                onCreateNote: (type) async {
                  await HapticFeedback.mediumImpact();
                  if (context.mounted) {
                    await context.push('/note/new?type=${type.name}');
                  }
                },
                onFromTemplate: () {
                  showTemplatePickerSheet(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeScroller(
    BuildContext context, {
    required List<Note> notes,
    required List<Note> filtered,
    required Map<NoteType?, int> counts,
    required bool isWide,
    required bool animate,
    required double safeBottom,
  }) {
    final scheme = Theme.of(context).colorScheme;

    // Batch-load card metadata (tags, notebooks, checklists, thumbnails)
    // so individual cards don't each fire 2+ DB queries.
    final metadataAsync = ref.watch(noteCardMetadataProvider(notes));
    final metadata = metadataAsync.when(
      data: (data) => data,
      loading: () => <String, NoteCardMetadata>{},
      error: (_, __) => <String, NoteCardMetadata>{},
    );

    Widget greeting = Text(
      _timeGreeting,
      style: TextStyle(
        fontFamily: 'Playfair Display',
        fontSize: isWide ? 28 : 24,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.2,
        height: 1.1,
        color: scheme.onSurface,
      ),
    );
    Widget vaultLabel = Text(
      'YOUR VAULT',
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.0,
        color: scheme.primary,
      ),
    );
    if (animate) {
      greeting = greeting.animate().fade(duration: 400.ms).slideY(begin: 0.2);
      vaultLabel = vaultLabel.animate().fade(delay: 150.ms, duration: 400.ms);
    }

    Widget searchPill = Padding(
      padding: EdgeInsets.fromLTRB(
        isWide ? 32 : 16,
        8,
        isWide ? 32 : 16,
        12,
      ),
      child: Semantics(
        label: 'Search thoughts, doodles, checklists...',
        button: true,
        hint: 'Opens note search',
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/home/search');
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: RepaintBoundary(
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      color: scheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Search thoughts, doodles, checklists...',
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${notes.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (animate) {
      searchPill = searchPill.animate().fade(delay: 200.ms, duration: 400.ms);
    }

    return PullToSearch(
      onTrigger: () {
        HapticFeedback.lightImpact();
        context.push('/home/search');
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar.large(
            expandedHeight: isWide ? 130.0 : 170.0,
            floating: false,
            pinned: true,
            backgroundColor: scheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: _isSelectionMode
                ? IconButton(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 22,
                    ),
                    tooltip: 'Exit selection',
                    onPressed: _exitSelectionMode,
                  )
                : null,
            actions: [
              if (!_isSelectionMode) ...[
                IconButton(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedSorting01,
                    size: 22,
                  ),
                  tooltip: 'Sort notes',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    NoteSortSheet.show(
                      context,
                      current: _sortOrder,
                      onSelected: (order) {
                        setState(() => _sortOrder = order);
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkSquare02,
                    size: 22,
                  ),
                  tooltip: 'Select notes',
                  onPressed: () => _enterSelectionMode(),
                ),
                const SizedBox(width: 8),
              ] else ...[
                TextButton.icon(
                  icon: HugeIcon(
                    icon: _selectedNoteIds.length == filtered.length &&
                            filtered.isNotEmpty
                        ? HugeIcons.strokeRoundedSquare
                        : HugeIcons.strokeRoundedCheckmarkBadge01,
                    size: 18,
                  ),
                  label: Text(
                    _selectedNoteIds.length == filtered.length &&
                            filtered.isNotEmpty
                        ? 'Deselect all'
                        : 'Select all',
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (_selectedNoteIds.length == filtered.length) {
                        _selectedNoteIds.clear();
                      } else {
                        _selectedNoteIds.addAll(filtered.map((n) => n.id));
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.symmetric(
                horizontal: isWide ? 32 : 24,
                vertical: 8,
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isSelectionMode)
                    Text(
                      _selectedNoteIds.isEmpty
                          ? 'Select notes'
                          : '${_selectedNoteIds.length} selected',
                      style: TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: isWide ? 28 : 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                        height: 1.1,
                        color: scheme.onSurface,
                      ),
                    )
                  else
                    greeting,
                  const SizedBox(height: 2),
                  if (_isSelectionMode)
                    Text(
                      'BATCH ACTIONS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: scheme.primary,
                      ),
                    )
                  else
                    vaultLabel,
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: searchPill,
          ),
          const SliverToBoxAdapter(child: UpdateBanner()),
          SliverToBoxAdapter(
            child: FilterPillBar(
              selectedType: _selectedType,
              counts: counts,
              onTypeSelected: (type) {
                HapticFeedback.selectionClick();
                setState(() => _selectedType = type);
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyHome(animate: widget.animate),
            )
          else if (isWide)
            _buildWideGrid(context, filtered, metadata)
          else
            _buildNarrowStream(filtered, metadata),
          SliverToBoxAdapter(child: SizedBox(height: safeBottom + 72)),
        ],
      ),
    );
  }

  Widget _buildNarrowStream(
      List<Note> filtered, Map<String, NoteCardMetadata> metadata) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          return RepaintBoundary(
            child:
                _buildAnimatedCard(context, filtered[index], index, metadata),
          );
        },
      ),
    );
  }

  Widget _buildWideGrid(
    BuildContext context,
    List<Note> filtered,
    Map<String, NoteCardMetadata> metadata,
  ) {
    // Interleave notes into columns for a masonry-like layout.
    final width = MediaQuery.sizeOf(context).width;
    // Use 3 columns only on extra-wide screens; 2 columns otherwise.
    final columnCount = width >= 1400 ? 3 : 2;
    final columns = <List<(Note, int)>>[];
    for (var i = 0; i < columnCount; i++) {
      columns.add([]);
    }
    for (var i = 0; i < filtered.length; i++) {
      columns[i % columnCount].add((filtered[i], i));
    }

    final rowCount =
        columns.map((c) => c.length).reduce((a, b) => a > b ? a : b);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList.builder(
        itemCount: rowCount,
        itemBuilder: (context, rowIndex) {
          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < columnCount; c++) ...[
                    if (c > 0) const SizedBox(width: 20),
                    Expanded(
                      child: rowIndex < columns[c].length
                          ? _buildAnimatedCard(
                              context,
                              columns[c][rowIndex].$1,
                              columns[c][rowIndex].$2,
                              metadata,
                            )
                          : const Spacer(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedCard(BuildContext context, Note note, int index,
      Map<String, NoteCardMetadata> metadata) {
    final noteMetadata = metadata[note.id];
    final isSelected = _selectedNoteIds.contains(note.id);
    Widget card;
    if (note.pinned) {
      card = NoteBannerCard(
        note: note,
        onTap: _isSelectionMode
            ? () => _toggleSelection(note.id)
            : () => _openNote(note.id),
        onLongPress: _isSelectionMode ? () => _toggleSelection(note.id) : null,
        onSelectNote: () => _enterSelectionMode(note.id),
        preloadedMetadata: noteMetadata,
      );
    } else if (note.type == NoteType.doodle || note.type == NoteType.mixed) {
      card = NoteDoodleCard(
        note: note,
        onTap: _isSelectionMode
            ? () => _toggleSelection(note.id)
            : () => _openNote(note.id),
        onLongPress: _isSelectionMode ? () => _toggleSelection(note.id) : null,
        onSelectNote: () => _enterSelectionMode(note.id),
        preloadedMetadata: noteMetadata,
      );
    } else {
      card = NoteMinimalCard(
        note: note,
        onTap: _isSelectionMode
            ? () => _toggleSelection(note.id)
            : () => _openNote(note.id),
        onLongPress: _isSelectionMode ? () => _toggleSelection(note.id) : null,
        onSelectNote: () => _enterSelectionMode(note.id),
        preloadedMetadata: noteMetadata,
      );
    }

    if (_isSelectionMode) {
      final scheme = Theme.of(context).colorScheme;
      card = Stack(
        children: [
          AnimatedScale(
            scale: isSelected ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: card,
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Semantics(
              label: isSelected ? 'Selected' : 'Not selected',
              checked: isSelected,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary
                        : scheme.surfaceContainerHighest
                            .withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? scheme.primary
                          : scheme.outlineVariant.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isSelected
                        ? const HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                            color: Colors.white,
                            size: 18,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (!_animationsAllowed(context)) return card;

    return ParallaxCard(
      child: card
          .animate()
          .fade(
            duration: 350.ms,
            delay: Duration(milliseconds: (index * 40).clamp(0, 400)),
          )
          .slideY(
            begin: 0.08,
            duration: 350.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }

  /// Material 3 window size class based on width.
  WindowSizeClass _windowSizeClass(double width) {
    if (width < 600) return WindowSizeClass.compact;
    if (width < 840) return WindowSizeClass.medium;
    if (width < 1200) return WindowSizeClass.expanded;
    return WindowSizeClass.large;
  }
}

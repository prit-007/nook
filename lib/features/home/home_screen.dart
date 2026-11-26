import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/adaptive_breakpoints.dart';
import '../../core/platform/home_widget_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/selection_providers.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/voice_preference_provider.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/nook_tokens.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../core/widgets/floating_undo_snackbar.dart';
import '../../core/widgets/parallax_card.dart';
import '../../core/widgets/resizable_split_view.dart';
import '../../data/database.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../data/tables/notes.dart';
import '../../sync/sync_orchestrator.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../editor/widgets/voice_capture_sheet.dart';
import '../templates/template_picker_sheet.dart';
import 'models/home_view_mode.dart';
import 'models/note_sort_order.dart';
import 'providers/notes_list_provider.dart';
import 'providers/note_card_metadata_provider.dart';
import 'widgets/batch_action_bar.dart';
import 'widgets/batch_action_sheets.dart';
import 'widgets/empty_home.dart';
import 'widgets/filter_pill_bar.dart';
import 'widgets/home_view_options_sheet.dart';
import 'widgets/morphing_editorial_fab.dart';
import 'widgets/nook_hero.dart';
import 'widgets/note_banner_card.dart';
import 'widgets/note_compact_tile.dart';
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
  bool _favoritesOnly = false;
  NoteSortOrder _sortOrder = NoteSortOrder.updatedDesc;
  HomeViewMode _viewMode = HomeViewMode.masonry;
  HomeGroupBy _groupBy = HomeGroupBy.none;
  final Set<String> _animatedNoteIds = {};
  bool _isSelectionMode = false;
  final Set<String> _selectedNoteIds = {};
  String _lastWidgetSyncSignature = '';

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
    var result = notes;
    if (_favoritesOnly) {
      result = result.where((n) => n.pinned).toList();
    }
    if (_selectedType != null) {
      result = result.where((n) => n.type == _selectedType).toList();
    }
    return result;
  }

  Map<NoteType?, int> _computeCounts(List<Note> notes) {
    final map = <NoteType?, int>{null: notes.length};
    for (final type in NoteType.values) {
      map[type] = notes.where((n) => n.type == type).length;
    }
    return map;
  }

  NookSyncStatus _mapSyncStatus(SyncOrchestratorState syncState) {
    if (syncState.conflicts.isNotEmpty) {
      return NookSyncStatus.conflict;
    }
    if (syncState.phase == SyncPhase.sending ||
        syncState.phase == SyncPhase.receiving ||
        syncState.phase == SyncPhase.connecting ||
        syncState.phase == SyncPhase.discovering ||
        syncState.phase == SyncPhase.resolving) {
      return NookSyncStatus.syncing;
    }
    if (syncState.phase == SyncPhase.complete) {
      return NookSyncStatus.synced;
    }
    return NookSyncStatus.localOnly;
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
                final sig = notes
                    .where((n) => n.pinned && !n.deleted && !n.locked)
                    .map((n) =>
                        '${n.id}:${n.title}:${n.updatedAt.millisecondsSinceEpoch}')
                    .join('|');
                if (sig != _lastWidgetSyncSignature) {
                  _lastWidgetSyncSignature = sig;
                  Future.microtask(
                    () => ref
                        .read(homeWidgetServiceProvider)
                        .syncPinnedNotes(notes),
                  );
                }
                final sortedNotes = _sortOrder.sort(notes);
                final filtered = _applyFilters(sortedNotes);
                final counts = _computeCounts(notes);
                final grid = _buildHomeScroller(
                  context,
                  notes: notes,
                  filtered: filtered,
                  counts: counts,
                  isWide: isWide,
                  width: width,
                  animate: animate,
                  safeBottom: safeBottom,
                );

                if (isDualPane) {
                  return ResizableSplitView(
                    storageKey: 'nook_home_split_ratio',
                    initialRatio:
                        sizeClass == WindowSizeClass.medium ? 0.45 : 0.40,
                    left: Container(
                      color: scheme.surfaceContainerLow.withValues(alpha: 0.3),
                      child: grid,
                    ),
                    right: const NotePreviewPane(),
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
    required double width,
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

    final syncState = ref.watch(syncOrchestratorProvider);
    final syncStatus = _mapSyncStatus(syncState);

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
          if (_isSelectionMode)
            SliverAppBar(
              pinned: true,
              backgroundColor: scheme.surface,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 22,
                ),
                tooltip: 'Exit selection',
                onPressed: _exitSelectionMode,
              ),
              title: Text(
                _selectedNoteIds.isEmpty
                    ? 'Select notes'
                    : '${_selectedNoteIds.length} selected',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: scheme.onSurface,
                ),
              ),
              actions: [
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
            )
          else
            NookHeroSliver(
              noteCount: notes.length,
              syncStatus: syncStatus,
              animate: widget.animate,
              onSearch: () {
                HapticFeedback.selectionClick();
                context.push('/home/search');
              },
              onSyncTap: () {
                HapticFeedback.selectionClick();
                context.push('/sync');
              },
              onCaptureText: () {
                HapticFeedback.selectionClick();
                context.push('/note/new?type=${NoteType.text.name}');
              },
              onCaptureChecklist: () {
                HapticFeedback.selectionClick();
                context.push('/note/new?type=${NoteType.checklist.name}');
              },
              onCaptureDoodle: () {
                HapticFeedback.selectionClick();
                context.push('/note/new?type=${NoteType.doodle.name}');
              },
              onCaptureVoice: ref.watch(voicePreferenceProvider).enabled
                  ? () async {
                      unawaited(HapticFeedback.selectionClick());
                      final text = await showVoiceCaptureSheet(context);
                      if (text == null || text.isEmpty || !context.mounted) {
                        return;
                      }
                      final db = ref.read(databaseProvider);
                      final repo = NoteRepository(db);
                      final note = await repo.createNote(
                        title: text.split('\n').first,
                        type: NoteType.text,
                        deviceOriginId: 'local',
                      );
                      await repo.updateContent(
                        note.id,
                        deltaContent: jsonEncode({
                          'document': {
                            'type': 'page',
                            'children': [
                              {
                                'type': 'paragraph',
                                'data': {
                                  'delta': [
                                    {'insert': text},
                                  ],
                                },
                              },
                            ],
                          },
                        }),
                        plainText: text,
                      );
                      if (context.mounted) {
                        await context.push('/note/${note.id}');
                      }
                    }
                  : null,
            ),
          SliverToBoxAdapter(
            child: FilterPillBar(
              selectedType: _selectedType,
              counts: counts,
              favoritesOnly: _favoritesOnly,
              onFavoritesToggled: (val) {
                HapticFeedback.selectionClick();
                setState(() => _favoritesOnly = val);
              },
              favoritesCount: notes.where((n) => n.pinned).length,
              onTypeSelected: (type) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedType = type;
                  if (type != null) _favoritesOnly = false;
                });
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedSorting01,
                      size: 20,
                    ),
                    tooltip: 'Sort notes',
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
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
                    icon: HugeIcon(
                      icon: _viewMode == HomeViewMode.masonry
                          ? HugeIcons.strokeRoundedGridView
                          : (_viewMode == HomeViewMode.list
                              ? HugeIcons.strokeRoundedListView
                              : HugeIcons.strokeRoundedMenu01),
                      size: 20,
                    ),
                    tooltip: 'View options',
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: () {
                      HomeViewOptionsSheet.show(
                        context,
                        currentViewMode: _viewMode,
                        currentGroupBy: _groupBy,
                        onViewModeChanged: (mode) =>
                            setState(() => _viewMode = mode),
                        onGroupByChanged: (group) =>
                            setState(() => _groupBy = group),
                      );
                    },
                  ),
                  IconButton(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckmarkSquare02,
                      size: 20,
                    ),
                    tooltip: 'Select notes',
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: () => _enterSelectionMode(),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: safeBottom + 72,
                  left: 24,
                  right: 24,
                ),
                child: EmptyHome(animate: widget.animate),
              ),
            )
          else
            ..._buildGroupedSlivers(
              context,
              filtered: filtered,
              metadata: metadata,
              isWide: isWide,
              width: width,
            ),
          SliverToBoxAdapter(child: SizedBox(height: safeBottom + 72)),
        ],
      ),
    );
  }

  Map<String, List<Note>> _groupNotes(List<Note> notes, HomeGroupBy groupBy) {
    if (groupBy == HomeGroupBy.none) {
      return {'': notes};
    }
    if (groupBy == HomeGroupBy.pinned) {
      final pinned = notes.where((n) => n.pinned).toList();
      final others = notes.where((n) => !n.pinned).toList();
      final groups = <String, List<Note>>{};
      if (pinned.isNotEmpty) groups['Pinned'] = pinned;
      if (others.isNotEmpty) {
        groups[pinned.isNotEmpty ? 'Others' : 'All notes'] = others;
      }
      return groups;
    }
    if (groupBy == HomeGroupBy.date) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final weekStart = todayStart.subtract(const Duration(days: 7));

      final today = <Note>[];
      final yesterday = <Note>[];
      final thisWeek = <Note>[];
      final older = <Note>[];

      for (final note in notes) {
        if (note.updatedAt.isAfter(todayStart)) {
          today.add(note);
        } else if (note.updatedAt.isAfter(yesterdayStart)) {
          yesterday.add(note);
        } else if (note.updatedAt.isAfter(weekStart)) {
          thisWeek.add(note);
        } else {
          older.add(note);
        }
      }

      final groups = <String, List<Note>>{};
      if (today.isNotEmpty) groups['Today'] = today;
      if (yesterday.isNotEmpty) groups['Yesterday'] = yesterday;
      if (thisWeek.isNotEmpty) groups['This week'] = thisWeek;
      if (older.isNotEmpty) groups['Older'] = older;
      return groups;
    }
    return {'': notes};
  }

  List<Widget> _buildGroupedSlivers(
    BuildContext context, {
    required List<Note> filtered,
    required Map<String, NoteCardMetadata> metadata,
    required bool isWide,
    required double width,
  }) {
    final groups = _groupNotes(filtered, _groupBy);
    final slivers = <Widget>[];

    for (final entry in groups.entries) {
      if (entry.key.isNotEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: entry.key,
              count: entry.value.length,
            ),
          ),
        );
      }

      slivers.add(
        _buildSliverForNotes(
          context,
          notes: entry.value,
          metadata: metadata,
          isWide: isWide,
          width: width,
        ),
      );
    }

    return slivers;
  }

  Widget _buildSliverForNotes(
    BuildContext context, {
    required List<Note> notes,
    required Map<String, NoteCardMetadata> metadata,
    required bool isWide,
    required double width,
  }) {
    if (_viewMode == HomeViewMode.compact) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 16),
        sliver: SliverList.separated(
          itemCount: notes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final note = notes[index];
            final isSelected = _selectedNoteIds.contains(note.id);
            return RepaintBoundary(
              child: _buildSwipeableCard(
                context: context,
                note: note,
                child: NoteCompactTile(
                  note: note,
                  isSelected: isSelected,
                  isSelectionMode: _isSelectionMode,
                  onTap: _isSelectionMode
                      ? () => _toggleSelection(note.id)
                      : () => _openNote(note.id),
                  onLongPress: _isSelectionMode
                      ? () => _toggleSelection(note.id)
                      : () => _enterSelectionMode(note.id),
                ),
              ),
            );
          },
        ),
      );
    }

    if (_viewMode == HomeViewMode.list) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 16),
        sliver: SliverList.separated(
          itemCount: notes.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final note = notes[index];
            return RepaintBoundary(
              child: _buildSwipeableCard(
                context: context,
                note: note,
                child: _buildAnimatedCard(context, note, index, metadata),
              ),
            );
          },
        ),
      );
    }

    // Default: HomeViewMode.masonry
    final crossAxisCount = isWide ? (width >= 1400 ? 3 : 2) : 2;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 24 : 16),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return RepaintBoundary(
            child: _buildSwipeableCard(
              context: context,
              note: note,
              child: _buildAnimatedCard(context, note, index, metadata),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwipeableCard({
    required BuildContext context,
    required Note note,
    required Widget child,
  }) {
    if (_isSelectionMode) {
      return child;
    }

    final scheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey('swipe_${note.id}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.85),
          borderRadius: context.tokens.borderRadiusMd,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedPin,
              color: scheme.onPrimaryContainer,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              note.pinned ? 'Unpin' : 'Pin',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: context.tokens.borderRadiusMd,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bin',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(width: 8),
            HugeIcon(
              icon: HugeIcons.strokeRoundedDelete01,
              color: scheme.onErrorContainer,
              size: 22,
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          try {
            await HapticFeedback.mediumImpact();
          } catch (_) {}
          final db = ref.read(databaseProvider);
          final repo = NoteRepository(db);
          await repo.updateNote(note.id, pinned: !note.pinned);
          return false;
        } else if (direction == DismissDirection.endToStart) {
          try {
            await HapticFeedback.mediumImpact();
          } catch (_) {}
          final db = ref.read(databaseProvider);
          final repo = NoteRepository(db);
          await repo.softDelete(note.id);
          if (context.mounted) {
            showUndoSnackBar(
              context,
              message:
                  'Moved "${note.title.trim().isEmpty ? 'Untitled note' : note.title.trim()}" to Bin',
              onUndo: () async {
                await repo.restore(note.id);
              },
            );
          }
          return true;
        }
        return false;
      },
      child: child,
    );
  }

  Widget _buildAnimatedCard(
    BuildContext context,
    Note note,
    int index,
    Map<String, NoteCardMetadata> metadata,
  ) {
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
            duration: AppMotion.short3,
            curve: AppMotion.emphasizedDecelerate,
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
                  duration: AppMotion.short4,
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

    final animAllowed = _animationsAllowed(context);
    final shouldAnimate = animAllowed && !_animatedNoteIds.contains(note.id);
    if (shouldAnimate) {
      _animatedNoteIds.add(note.id);
      card = card
          .animate()
          .fade(
            duration: AppMotion.medium1,
            delay: AppMotion.staggerDelay(index % 6),
            curve: AppMotion.emphasizedDecelerate,
          )
          .slideY(
            begin: 0.08,
            duration: AppMotion.medium1,
            curve: AppMotion.emphasizedDecelerate,
          );
    }

    if (animAllowed && _viewMode == HomeViewMode.masonry) {
      return ParallaxCard(child: card);
    }

    return card;
  }

  /// Material 3 window size class based on width.
  WindowSizeClass _windowSizeClass(double width) {
    if (width < 600) return WindowSizeClass.compact;
    if (width < 840) return WindowSizeClass.medium;
    if (width < 1200) return WindowSizeClass.expanded;
    return WindowSizeClass.large;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: context.tokens.borderRadiusXs,
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

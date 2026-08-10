import 'dart:ui';

import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/database_provider.dart';
import '../../data/database.dart';
import '../../data/tables/notes.dart';
import 'providers/notes_list_provider.dart';
import 'widgets/empty_home.dart';
import 'widgets/filter_pill_bar.dart';
import 'widgets/morphing_editorial_fab.dart';
import 'widgets/note_banner_card.dart';
import 'widgets/note_doodle_card.dart';
import 'widgets/note_minimal_card.dart';
import 'widgets/pull_to_search.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.animate = true});

  final bool animate;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  NoteType? _selectedType;

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning thoughts.';
    if (hour < 17) return 'Afternoon flow.';
    if (hour < 22) return 'Evening reflections.';
    return 'Late night ideas.';
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
    context.push('/note/$noteId');
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 600;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: notesAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: scheme.primary),
        ),
        error: (e, _) => Center(child: Text('Error loading vault: $e')),
        data: (notes) {
          final filtered = _applyFilters(notes);
          final counts = _computeCounts(notes);

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
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: EdgeInsets.symmetric(
                      horizontal: isWide ? 32 : 24,
                      vertical: 16,
                    ),
                    title: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _timeGreeting,
                          style: TextStyle(
                            fontSize: isWide ? 22 : 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                            color: scheme.onSurface,
                          ),
                        ).animate().fade(duration: 400.ms).slideY(begin: 0.2),
                        const SizedBox(height: 2),
                        Text(
                          'YOUR VAULT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color: scheme.primary,
                          ),
                        ).animate().fade(delay: 150.ms, duration: 400.ms),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isWide ? 32 : 16,
                      8,
                      isWide ? 32 : 16,
                      12,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/home/search');
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: scheme.outlineVariant
                                    .withValues(alpha: 0.25),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  color: scheme.primary,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Search thoughts, doodles, checklists...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: scheme.onSurfaceVariant
                                          .withValues(alpha: 0.7),
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
                  ).animate().fade(delay: 200.ms, duration: 400.ms),
                ),
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
                  _buildWideGrid(filtered)
                else
                  _buildNarrowStream(filtered),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: MorphingEditorialFab(
        onCreateNote: (type) async {
          await HapticFeedback.mediumImpact();
          final db = ref.read(databaseProvider);
          final id = await db.into(db.notes).insert(
                NotesCompanion.insert(
                  title: const Value(''),
                  type: type,
                  deviceOriginId: 'local',
                ),
              );
          if (context.mounted) {
            await context.push('/note/$id');
          }
        },
      ),
    );
  }

  Widget _buildNarrowStream(List<Note> filtered) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          return _buildAnimatedCard(filtered[index], index);
        },
      ),
    );
  }

  Widget _buildWideGrid(List<Note> filtered) {
    final left = <(Note, int)>[];
    final right = <(Note, int)>[];
    for (var i = 0; i < filtered.length; i++) {
      if (i.isEven) {
        left.add((filtered[i], i));
      } else {
        right.add((filtered[i], i));
      }
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverToBoxAdapter(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  for (final pair in left) _buildAnimatedCard(pair.$1, pair.$2),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  for (final pair in right)
                    _buildAnimatedCard(pair.$1, pair.$2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCard(Note note, int index) {
    Widget card;
    if (note.pinned) {
      card = NoteBannerCard(note: note, onTap: () => _openNote(note.id));
    } else if (note.type == NoteType.doodle) {
      card = NoteDoodleCard(note: note, onTap: () => _openNote(note.id));
    } else {
      card = NoteMinimalCard(note: note, onTap: () => _openNote(note.id));
    }

    return card
        .animate()
        .fade(
          duration: 350.ms,
          delay: Duration(milliseconds: (index * 40).clamp(0, 400)),
        )
        .slideY(
          begin: 0.08,
          duration: 350.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

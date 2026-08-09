import 'dart:ui';

import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:flutter/material.dart';
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

/// Home screen — editorial vault layout with CustomScrollView, slivers,
/// asymmetric card stream, and morphing FAB.
/// Responsive: single-column stream on mobile, 2-column grid on tablet+.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  NoteType? _selectedType;

  List<Note> _applyFilters(List<Note> notes) {
    if (_selectedType == null) return notes;
    return notes.where((n) => n.type == _selectedType).toList();
  }

  void _openNote(String noteId) {
    context.push('/note/$noteId');
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 600;

    return Scaffold(
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notes) {
          final filtered = _applyFilters(notes);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // 1. Massive Editorial Header
              SliverAppBar.large(
                expandedHeight: isWide ? 120.0 : 160.0,
                floating: false,
                pinned: true,
                backgroundColor: scheme.surface,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: EdgeInsets.symmetric(
                    horizontal: isWide ? 32 : 24,
                    vertical: 16,
                  ),
                  title: Text(
                    'Own Your Notes.',
                    style: TextStyle(
                      fontSize: isWide ? 24 : 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),

              // 2. Search bar (glassmorphism)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 32 : 16,
                    8,
                    isWide ? 32 : 16,
                    4,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: isWide ? 600 : double.infinity),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: scheme.outlineVariant.withValues(alpha: 0.2),
                          ),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search your vault...',
                            hintStyle: TextStyle(
                              color: scheme.onSurfaceVariant,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: scheme.onSurfaceVariant,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Horizontal Quick-Filter Pill Bar
              SliverToBoxAdapter(
                child: FilterPillBar(
                  selectedType: _selectedType,
                  onTypeSelected: (type) {
                    setState(() => _selectedType = type);
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // 4. Notes stream or empty state
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyHome(),
                )
              else if (isWide)
                _buildWideGrid(filtered)
              else
                _buildNarrowStream(filtered),

              // 5. Bottom padding for FAB
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
      floatingActionButton: MorphingEditorialFab(
        onCreateNote: (type) async {
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

  /// Narrow (< 600px): single-column asymmetric stream.
  Widget _buildNarrowStream(List<Note> filtered) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          return _buildCardForNote(filtered[index]);
        },
      ),
    );
  }

  /// Wide (>= 600px): 2-column masonry-like grid.
  Widget _buildWideGrid(List<Note> filtered) {
    final left = <Note>[];
    final right = <Note>[];
    for (var i = 0; i < filtered.length; i++) {
      if (i.isEven) {
        left.add(filtered[i]);
      } else {
        right.add(filtered[i]);
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
                  for (final note in left) _buildCardForNote(note),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  for (final note in right) _buildCardForNote(note),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardForNote(Note note) {
    if (note.pinned) {
      return NoteBannerCard(
        note: note,
        onTap: () => _openNote(note.id),
      );
    }

    if (note.type == NoteType.doodle) {
      return NoteDoodleCard(
        note: note,
        onTap: () => _openNote(note.id),
      );
    }

    return NoteMinimalCard(
      note: note,
      onTap: () => _openNote(note.id),
    );
  }
}

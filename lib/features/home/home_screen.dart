import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/adaptive_breakpoints.dart';
import '../../core/providers/selection_providers.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/widgets/parallax_card.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../data/database.dart';
import '../../data/tables/notes.dart';
import 'providers/notes_list_provider.dart';
import 'widgets/empty_home.dart';
import 'widgets/filter_pill_bar.dart';
import 'widgets/morphing_editorial_fab.dart';
import 'widgets/note_banner_card.dart';
import 'widgets/note_doodle_card.dart';
import 'widgets/note_minimal_card.dart';
import 'widgets/note_preview_pane.dart';
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
    if (AdaptiveBreakpoints.supportsDualPane(context)) {
      ref.read(selectedNoteIdProvider.notifier).state = noteId;
      return;
    }
    context.push('/note/$noteId');
  }

  bool _animationsAllowed(BuildContext context) {
    final preferredOff = ref.read(themePreferenceProvider).reduceMotion;
    return !preferredOff && !MediaQuery.disableAnimationsOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListProvider);
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 600;
    final isDualPane = AdaptiveBreakpoints.supportsDualPane(context);
    final animate = _animationsAllowed(context);

    // The shell already offsets the body by the full dock height (72 + 24 +
    // bottom inset), so the FAB only needs a small gap above the body's bottom
    // edge — no need to re-add the dock height here.
    final safeBottom = DockSafeArea.bottomOf(context) + 16;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
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
              final filtered = _applyFilters(notes);
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
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(flex: 3, child: grid),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                    const Flexible(flex: 2, child: NotePreviewPane()),
                  ],
                );
              }
              return grid;
            },
          ),
          MorphingEditorialFab(
            mobileBottomOffset: safeBottom,
            onCreateNote: (type) async {
              await HapticFeedback.mediumImpact();
              if (context.mounted) {
                await context.push('/note/new?type=${type.name}');
              }
            },
          ),
        ],
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
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(24),
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
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.symmetric(
                horizontal: isWide ? 32 : 24,
                vertical: 8,
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  greeting,
                  const SizedBox(height: 2),
                  vaultLabel,
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: searchPill,
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
          SliverToBoxAdapter(child: SizedBox(height: safeBottom + 72)),
        ],
      ),
    );
  }

  Widget _buildNarrowStream(List<Note> filtered) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          return _buildAnimatedCard(context, filtered[index], index);
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
                  for (final pair in left)
                    _buildAnimatedCard(context, pair.$1, pair.$2),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  for (final pair in right)
                    _buildAnimatedCard(context, pair.$1, pair.$2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCard(BuildContext context, Note note, int index) {
    Widget card;
    if (note.pinned) {
      card = NoteBannerCard(note: note, onTap: () => _openNote(note.id));
    } else if (note.type == NoteType.doodle) {
      card = NoteDoodleCard(note: note, onTap: () => _openNote(note.id));
    } else {
      card = NoteMinimalCard(note: note, onTap: () => _openNote(note.id));
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
}

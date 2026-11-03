import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/database_provider.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/repositories/search_repository.dart';
import 'widgets/note_card.dart';

/// Search screen — instant FTS search with real-time results, grouped by
/// note matches vs checklist-item matches.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  GroupedSearchResults _results = const GroupedSearchResults();
  bool _searched = false;
  bool _searching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _query = query;
      _searched = true;
      _searching = true;
    });
    if (query.trim().isEmpty) {
      setState(() {
        _results = const GroupedSearchResults();
        _searching = false;
      });
      return;
    }
    try {
      final db = ref.read(databaseProvider);
      final repo = SearchRepository(db);
      final results = await repo.searchGrouped(query);
      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: const InputDecoration(
            hintText: 'Search notes...',
            border: InputBorder.none,
          ),
          onChanged: (text) {
            setState(() {});
            _onSearchChanged(text);
          },
        ),
        leading: IconButton(
          icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01, size: 24),
          tooltip: 'Go back',
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedCancel01,
                size: 20,
              ),
              tooltip: 'Clear search',
              onPressed: () {
                HapticFeedback.lightImpact();
                _controller.clear();
                _search('');
              },
            ),
        ],
      ),
      body: _query.trim().isEmpty
          ? SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  const EmptyState(
                    icon: HugeIcons.strokeRoundedSearch01,
                    title: 'Search notes',
                    subtitle: 'Type words, tags, or choose a category below',
                    animate: false,
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _QuickFilterChip(
                        icon: HugeIcons.strokeRoundedTask01,
                        label: 'Checklists',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _controller.text = 'checklist';
                          _search('checklist');
                        },
                      ),
                      _QuickFilterChip(
                        icon: HugeIcons.strokeRoundedPencilEdit02,
                        label: 'Doodles',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _controller.text = 'doodle';
                          _search('doodle');
                        },
                      ),
                      _QuickFilterChip(
                        icon: HugeIcons.strokeRoundedPin,
                        label: 'Pinned',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _controller.text = 'pinned';
                          _search('pinned');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            )
          : _searching
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty && _searched
                  ? EmptyState(
                      icon: HugeIcons.strokeRoundedSearch02,
                      title: 'No results',
                      subtitle: 'No notes found for "$_query"',
                      animate: false,
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        if (_results.notes.isNotEmpty) ...[
                          _SectionHeader(
                            title: 'Notes',
                            count: _results.notes.length,
                            scheme: scheme,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final crossAxisCount =
                                    constraints.maxWidth > 600 ? 3 : 2;
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 0.75,
                                  ),
                                  itemCount: _results.notes.length,
                                  itemBuilder: (context, index) {
                                    final note = _results.notes[index];
                                    return NoteCard(
                                      note: note,
                                      onTap: () =>
                                          context.push('/note/${note.id}'),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                        if (_results.checklistItems.isNotEmpty) ...[
                          _SectionHeader(
                            title: 'Checklist items',
                            count: _results.checklistItems.length,
                            scheme: scheme,
                          ),
                          for (final hit in _results.checklistItems)
                            ListTile(
                              leading: HugeIcon(
                                icon: HugeIcons.strokeRoundedTask01,
                                size: 22,
                                color: scheme.primary,
                              ),
                              title: Text(hit.snippet ?? ''),
                              subtitle: Text(
                                hit.note.title.isEmpty
                                    ? 'Untitled'
                                    : hit.note.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                              onTap: () => context.push('/note/${hit.note.id}'),
                            ),
                        ],
                      ],
                    ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.scheme,
  });

  final String title;
  final int count;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(icon: icon, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

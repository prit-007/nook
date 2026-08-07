import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/database_provider.dart';
import '../../data/database.dart';
import '../../data/tables/notes.dart';
import 'widgets/note_card.dart';

/// Home screen — notes grid with search bar, filter chips, FAB.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  NoteType? _selectedType;
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final db = ref.read(databaseProvider);
    final results = await (db.select(db.notes)
          ..where((t) => t.deleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.pinned),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .get();
    setState(() {
      _notes = results;
      _loading = false;
    });
  }

  List<Note> get _filteredNotes {
    var result = _notes;
    if (_selectedType != null) {
      result = result.where((n) => n.type == _selectedType).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (n) =>
                n.title.toLowerCase().contains(q) ||
                (n.plainText?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredNotes;

    return Scaffold(
      appBar: AppBar(title: const Text('Nook')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _selectedType == null,
                  onTap: () => setState(() => _selectedType = null),
                ),
                _FilterChip(
                  label: 'Text',
                  selected: _selectedType == NoteType.text,
                  onTap: () => setState(() => _selectedType = NoteType.text),
                ),
                _FilterChip(
                  label: 'Checklist',
                  selected: _selectedType == NoteType.checklist,
                  onTap: () =>
                      setState(() => _selectedType = NoteType.checklist),
                ),
                _FilterChip(
                  label: 'Doodle',
                  selected: _selectedType == NoteType.doodle,
                  onTap: () => setState(() => _selectedType = NoteType.doodle),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Notes grid
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.note_add_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.15),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notes',
                              style: TextStyle(
                                fontSize: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotes,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) =>
                              NoteCard(note: filtered[index]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final db = ref.read(databaseProvider);
          final id = await db.into(db.notes).insert(
                NotesCompanion.insert(
                  title: const Value(''),
                  type: NoteType.text,
                  deviceOriginId: 'local',
                ),
              );
          if (context.mounted) {
            await context.push('/note/$id');
            await _loadNotes();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

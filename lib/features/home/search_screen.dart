import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/database_provider.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/database.dart';
import '../../data/repositories/search_repository.dart';
import 'widgets/note_card.dart';

/// Search screen — instant FTS search with real-time results.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  List<Note> _results = [];
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() {
      _query = query;
      _searched = true;
    });
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final db = ref.read(databaseProvider);
    final repo = SearchRepository(db);
    final results = await repo.searchNotes(query);
    if (mounted) {
      setState(() => _results = results);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: const InputDecoration(
            hintText: 'Search notes...',
            border: InputBorder.none,
          ),
          onChanged: _search,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _query.trim().isEmpty
          ? const EmptyState(
              icon: Icons.search_rounded,
              title: 'Search notes',
              subtitle: 'Type to find your notes',
              animate: false,
            )
          : _results.isEmpty && _searched
              ? EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No results',
                  subtitle: 'No notes found for "$_query"',
                  animate: false,
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (context, index) =>
                      NoteCard(note: _results[index]),
                ),
    );
  }
}

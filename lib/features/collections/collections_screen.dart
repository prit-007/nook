import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/navigation_preference.dart';

import '../notebooks/notebooks_screen.dart';
import '../tags/tags_screen.dart';

/// Unified notebooks/tags workspace. Both routes open this screen so the
/// top-level destination is shared while preserving deep-link entry state.
class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 1).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedTab == 0 ? 'Library' : 'Tags'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                    value: 0,
                    label: Text('Notebooks'),
                    icon: Icon(Icons.book_outlined)),
                ButtonSegment(
                    value: 1,
                    label: Text('Tags'),
                    icon: Icon(Icons.label_outline)),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (value) {
                final tab = value.first;
                setState(() => _selectedTab = tab);
                final route = tab == 0 ? '/notebooks' : '/tags';
                NavigationPreference.rememberPath(route);
                context.go(route);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: const [
          NotebooksScreen(embedded: true),
          TagsScreen(embedded: true),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/widgets/dock_safe_area.dart';
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

  /// Registered create callbacks from the embedded child screens.
  VoidCallback? _createNotebookAction;
  VoidCallback? _createTagAction;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 1).toInt();
  }

  void _onFabPressed() {
    HapticFeedback.mediumImpact();
    if (_selectedTab == 0) {
      _createNotebookAction?.call();
    } else {
      _createTagAction?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safeBottom = DockSafeArea.bottomOf(context) + 16;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedTab == 0 ? 'Library' : 'Tags'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                    value: 0,
                    label: const Text('Notebooks'),
                    icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedBook01,
                        size: 20,
                        color: scheme.onSurface)),
                ButtonSegment(
                    value: 1,
                    label: const Text('Tags'),
                    icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedTag01,
                        size: 20,
                        color: scheme.onSurface)),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (value) {
                final tab = value.first;
                setState(() => _selectedTab = tab);
                final route = tab == 0 ? '/notebooks' : '/tags';
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
        children: [
          NotebooksScreen(
            embedded: true,
            onCreateRegistered: (action) => _createNotebookAction = action,
          ),
          TagsScreen(
            embedded: true,
            onCreateRegistered: (action) => _createTagAction = action,
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: safeBottom),
        child: FloatingActionButton.extended(
          heroTag: 'fab-collections',
          onPressed: _onFabPressed,
          tooltip: _selectedTab == 0 ? 'Create notebook' : 'Create tag',
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedAdd01,
            size: 24,
            color: scheme.onPrimary,
          ),
          label: Text(
            _selectedTab == 0 ? 'New Collection' : 'New Tag',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

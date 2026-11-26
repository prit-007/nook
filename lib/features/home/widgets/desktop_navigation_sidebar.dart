import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/database.dart';
import '../../../data/repositories/notebook_repository.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../data/tables/notes.dart';

/// Desktop 3-pane navigation sidebar for widescreen monitors (>= 1200dp).
///
/// Houses quick collections, nested notebook trees, tags, and system links.
class DesktopNavigationSidebar extends ConsumerStatefulWidget {
  const DesktopNavigationSidebar({
    super.key,
    required this.selectedType,
    required this.favoritesOnly,
    required this.selectedNotebookId,
    required this.counts,
    required this.favoritesCount,
    required this.onSelectAll,
    required this.onSelectFavorites,
    required this.onSelectType,
    required this.onSelectNotebook,
  });

  final NoteType? selectedType;
  final bool favoritesOnly;
  final String? selectedNotebookId;
  final Map<NoteType?, int> counts;
  final int favoritesCount;
  final VoidCallback onSelectAll;
  final ValueChanged<bool> onSelectFavorites;
  final ValueChanged<NoteType?> onSelectType;
  final ValueChanged<String?> onSelectNotebook;

  @override
  ConsumerState<DesktopNavigationSidebar> createState() =>
      _DesktopNavigationSidebarState();
}

class _DesktopNavigationSidebarState
    extends ConsumerState<DesktopNavigationSidebar> {
  List<Notebook> _notebooks = [];
  List<Tag> _tags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final db = ref.read(databaseProvider);
    final nbRepo = NotebookRepository(db);
    final tagRepo = TagRepository(db);
    final nbs = await nbRepo.getAllNotebooks();
    final tags = await tagRepo.getAllTags();
    if (!mounted) return;
    setState(() {
      _notebooks = nbs;
      _tags = tags;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAllSelected = widget.selectedType == null &&
        !widget.favoritesOnly &&
        widget.selectedNotebookId == null;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.4),
        border: Border(
          right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedFolderLibrary,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Workspace',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: scheme.onSurface,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _SectionHeader(title: 'QUICK VIEWS', scheme: scheme),
                _SidebarItem(
                  icon: HugeIcons.strokeRoundedFile01,
                  label: 'All Notes',
                  count: widget.counts[null] ?? 0,
                  isSelected: isAllSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onSelectAll();
                  },
                ),
                _SidebarItem(
                  icon: HugeIcons.strokeRoundedStar,
                  label: 'Pinned',
                  count: widget.favoritesCount,
                  isSelected: widget.favoritesOnly,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onSelectFavorites(!widget.favoritesOnly);
                  },
                ),
                _SidebarItem(
                  icon: HugeIcons.strokeRoundedCheckmarkSquare02,
                  label: 'Checklists',
                  count: widget.counts[NoteType.checklist] ?? 0,
                  isSelected: widget.selectedType == NoteType.checklist,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onSelectType(NoteType.checklist);
                  },
                ),
                _SidebarItem(
                  icon: HugeIcons.strokeRoundedPencil,
                  label: 'Doodles',
                  count: widget.counts[NoteType.doodle] ?? 0,
                  isSelected: widget.selectedType == NoteType.doodle,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onSelectType(NoteType.doodle);
                  },
                ),
                const SizedBox(height: 16),
                _SectionHeader(
                  title: 'NOTEBOOKS',
                  scheme: scheme,
                  trailing: IconButton(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedPlusSign,
                      size: 16,
                    ),
                    tooltip: 'View Notebooks',
                    onPressed: () => context.push('/notebooks'),
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_notebooks.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'No notebooks yet',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  )
                else
                  ..._buildNestedNotebookItems(scheme),
                const SizedBox(height: 16),
                if (_tags.isNotEmpty) ...[
                  _SectionHeader(title: 'TAGS', scheme: scheme),
                  for (final tag in _tags)
                    _SidebarItem(
                      icon: HugeIcons.strokeRoundedTag01,
                      label: tag.name,
                      isSelected: false,
                      onTap: () => context.push('/tags/${tag.id}'),
                    ),
                  const SizedBox(height: 16),
                ],
                _SectionHeader(title: 'SYSTEM', scheme: scheme),
                _SidebarItem(
                  icon: HugeIcons.strokeRoundedArchive,
                  label: 'Archive',
                  isSelected: false,
                  onTap: () => context.push('/archive'),
                ),
                _SidebarItem(
                  icon: HugeIcons.strokeRoundedDelete02,
                  label: 'Trash',
                  isSelected: false,
                  onTap: () => context.push('/trash'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNestedNotebookItems(ColorScheme scheme) {
    final widgets = <Widget>[];
    // Separate root notebooks and sub-notebooks
    final roots = _notebooks.where((nb) => nb.parentId == null).toList();
    final subMap = <String, List<Notebook>>{};
    for (final nb in _notebooks.where((nb) => nb.parentId != null)) {
      subMap.putIfAbsent(nb.parentId!, () => []).add(nb);
    }

    for (final root in roots) {
      final isSelected = widget.selectedNotebookId == root.id;
      final seed = NookColors.parseHex(root.colorSeed);
      widgets.add(
        _SidebarItem(
          customLeading: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: seed,
              shape: BoxShape.circle,
            ),
          ),
          label: root.name,
          isSelected: isSelected,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onSelectNotebook(isSelected ? null : root.id);
          },
        ),
      );

      // Render children if present
      final children = subMap[root.id] ?? [];
      for (final child in children) {
        final isChildSelected = widget.selectedNotebookId == child.id;
        final childSeed = NookColors.parseHex(child.colorSeed);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _SidebarItem(
              customLeading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 14,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: childSeed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              label: child.name.contains('/')
                  ? child.name.split('/').last.trim()
                  : child.name,
              isSelected: isChildSelected,
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onSelectNotebook(isChildSelected ? null : child.id);
              },
            ),
          ),
        );
      }
    }
    return widgets;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.scheme,
    this.trailing,
  });

  final String title;
  final ColorScheme scheme;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    this.icon,
    this.customLeading,
    required this.label,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  final dynamic icon;
  final Widget? customLeading;
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected
          ? scheme.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              if (customLeading != null)
                customLeading!
              else if (icon != null)
                HugeIcon(
                  icon: icon,
                  size: 18,
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
              if (count != null && count! > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? scheme.primary.withValues(alpha: 0.18)
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

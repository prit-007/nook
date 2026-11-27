import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/nook_tokens.dart';
import '../controllers/collection_tree_controller.dart';

/// Mobile drill-down collection navigator.
///
/// Instead of deep nesting which cramps mobile screens, this renders:
/// 1. Breadcrumbs showing current path (e.g. `‹ Work / Projects`)
/// 2. Sub-collection chips (e.g. `[ Nook · 4 ] [ Meetings · 5 ]`)
/// 3. Current collection content or child collection cards.
class MobileCollectionDrillDown extends StatefulWidget {
  const MobileCollectionDrillDown({
    super.key,
    required this.nodes,
    required this.onSelectCollection,
    this.initialCollectionId,
  });

  final List<CollectionTreeNode> nodes;
  final ValueChanged<String?> onSelectCollection;
  final String? initialCollectionId;

  @override
  State<MobileCollectionDrillDown> createState() =>
      _MobileCollectionDrillDownState();
}

class _MobileCollectionDrillDownState extends State<MobileCollectionDrillDown> {
  final List<CollectionTreeNode> _pathStack = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialCollectionId != null) {
      _findAndSetInitialPath(widget.nodes, widget.initialCollectionId!);
    }
  }

  bool _findAndSetInitialPath(
      List<CollectionTreeNode> currentNodes, String targetId) {
    for (final node in currentNodes) {
      _pathStack.add(node);
      if (node.id == targetId) {
        return true;
      }
      if (_findAndSetInitialPath(node.children, targetId)) {
        return true;
      }
      _pathStack.removeLast();
    }
    return false;
  }

  void _drillInto(CollectionTreeNode node) {
    setState(() {
      _pathStack.add(node);
    });
    widget.onSelectCollection(node.id);
  }

  void _navigateUp() {
    if (_pathStack.isNotEmpty) {
      setState(() {
        _pathStack.removeLast();
      });
      final currentId = _pathStack.isNotEmpty ? _pathStack.last.id : null;
      widget.onSelectCollection(currentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final isAtRoot = _pathStack.isEmpty;
    final currentChildren = isAtRoot ? widget.nodes : _pathStack.last.children;

    return Column(
      key: const Key('mobile_drill_down'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Breadcrumb bar
        if (!isAtRoot)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: _navigateUp,
                  borderRadius: tokens.borderRadiusPill,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowLeft01,
                          size: 16,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _pathStack.length > 1
                              ? _pathStack[_pathStack.length - 2].name
                              : 'Collections',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  ' / ',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                Expanded(
                  child: Text(
                    _pathStack.last.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Sub-collection chips
        if (!isAtRoot && currentChildren.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: currentChildren.map((child) {
                final seed = NookColors.parseHex(child.colorSeed);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: seed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    label: Text('${child.name} · ${child.noteCount}'),
                    onPressed: () => _drillInto(child),
                    shape: RoundedRectangleBorder(
                      borderRadius: tokens.borderRadiusPill,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        // Level grid / list
        Expanded(
          child: currentChildren.isEmpty
              ? Center(
                  child: Text(
                    'No sub-collections in this section',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: currentChildren.length,
                  itemBuilder: (context, index) {
                    final item = currentChildren[index];
                    final seed = NookColors.parseHex(item.colorSeed);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                        borderRadius: tokens.borderRadiusMd,
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: seed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${item.noteCount} ${item.noteCount == 1 ? 'note' : 'notes'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: item.children.isNotEmpty
                            ? HugeIcon(
                                icon: HugeIcons.strokeRoundedArrowRight01,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              )
                            : null,
                        onTap: () {
                          if (item.children.isNotEmpty) {
                            _drillInto(item);
                          } else {
                            widget.onSelectCollection(item.id);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

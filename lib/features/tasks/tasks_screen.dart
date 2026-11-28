import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/database_provider.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/nook_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/database.dart';
import '../../data/repositories/checklist_item_repository.dart';

/// Cross-note task view aggregating all open checklist items across live,
/// unlocked, non-archived notes.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  List<({ChecklistItem item, Note note})> _tasks = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);
    final tasks = await repo.getOpenTasksAcrossNotes();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  Future<void> _toggleTask(ChecklistItem item) async {
    unawaited(HapticFeedback.selectionClick());
    final db = ref.read(databaseProvider);
    final repo = ChecklistItemRepository(db);
    await repo.toggleChecked(item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Open Tasks'),
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            size: 24,
          ),
          tooltip: 'Go back',
          onPressed: () => context.pop(),
        ),
      ),
      body: AnimatedSwitcher(
        duration: AppMotion.standard,
        switchInCurve: AppMotion.emphasizedDecelerate,
        switchOutCurve: AppMotion.emphasizedAccelerate,
        child: _loading
            ? const Center(
                key: ValueKey('tasks-loading'),
                child: CircularProgressIndicator(),
              )
            : _tasks.isEmpty
                ? const EmptyState(
                    key: ValueKey('tasks-empty'),
                    icon: HugeIcons.strokeRoundedCheckList,
                    title: 'All caught up',
                    subtitle:
                        'Open checklist items across your notes appear here',
                  )
                : ListView.separated(
                    key: ValueKey('tasks-list-${_tasks.length}'),
                    padding: const EdgeInsets.all(NookTokens.kSpacingLg),
                    itemCount: _tasks.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: NookTokens.kSpacingSm),
                    itemBuilder: (context, index) {
                      final entry = _tasks[index];
                      final noteTitle = entry.note.title.trim().isEmpty
                          ? 'Untitled'
                          : entry.note.title.trim();
                      return Material(
                        color: scheme.surfaceContainerLow,
                        borderRadius:
                            BorderRadius.circular(NookTokens.kRadiusMd),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(NookTokens.kRadiusMd),
                          ),
                          leading: Checkbox(
                            value: entry.item.checked,
                            onChanged: (_) => _toggleTask(entry.item),
                          ),
                          title: Text(
                            entry.item.itemText,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            noteTitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowRight01,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                          onTap: () => context.push('/note/${entry.note.id}'),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

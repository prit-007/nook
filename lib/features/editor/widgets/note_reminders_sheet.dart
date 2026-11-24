import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../core/platform/local_reminder_scheduler.dart';
import '../../../core/providers/database_provider.dart';
import '../../../data/database.dart';
import '../../../data/repositories/reminder_repository.dart';

/// Modal bottom sheet for scheduling and managing local reminders for a note.
Future<void> showNoteRemindersSheet(
  BuildContext context, {
  required String noteId,
  required String noteTitle,
  ReminderScheduler? scheduler,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => NoteRemindersSheet(
      noteId: noteId,
      noteTitle: noteTitle,
      scheduler: scheduler,
    ),
  );
}

class NoteRemindersSheet extends ConsumerStatefulWidget {
  const NoteRemindersSheet({
    super.key,
    required this.noteId,
    required this.noteTitle,
    this.scheduler,
  });

  final String noteId;
  final String noteTitle;
  final ReminderScheduler? scheduler;

  @override
  ConsumerState<NoteRemindersSheet> createState() => _NoteRemindersSheetState();
}

class _NoteRemindersSheetState extends ConsumerState<NoteRemindersSheet> {
  List<Reminder> _reminders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final repo = ReminderRepository(
      db,
      scheduler: widget.scheduler ?? LocalReminderScheduler(),
    );
    final reminders = await repo.forNote(widget.noteId);
    if (!mounted) return;
    setState(() {
      _reminders = reminders;
      _loading = false;
    });
  }

  Future<void> _addReminder() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (pickedTime == null || !mounted) return;

    final fireAt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    final db = ref.read(databaseProvider);
    final repo = ReminderRepository(
      db,
      scheduler: widget.scheduler ?? LocalReminderScheduler(),
    );
    await repo.create(
      noteId: widget.noteId,
      title: widget.noteTitle.isNotEmpty ? widget.noteTitle : 'Nook reminder',
      fireAt: fireAt,
    );

    await _load();
  }

  Future<void> _deleteReminder(String id) async {
    final db = ref.read(databaseProvider);
    final repo = ReminderRepository(
      db,
      scheduler: widget.scheduler ?? LocalReminderScheduler(),
    );
    await repo.delete(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAlarmClock,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Reminders',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              FilledButton.tonalIcon(
                onPressed: _addReminder,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedPlusSign,
                  size: 16,
                ),
                label: const Text('Add reminder'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else if (_reminders.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  'No reminders scheduled yet',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _reminders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final r = _reminders[index];
                  final formattedDate =
                      DateFormat.yMMMd().add_jm().format(r.fireAt);

                  return Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: scheme.surfaceContainerLow,
                      leading: HugeIcon(
                        icon: HugeIcons.strokeRoundedClock01,
                        size: 20,
                        color: scheme.primary,
                      ),
                      title: Text(
                        r.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Delete reminder',
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedDelete02,
                          size: 18,
                          color: scheme.error,
                        ),
                        onPressed: () => _deleteReminder(r.id),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

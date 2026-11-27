import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../core/platform/local_reminder_scheduler.dart';
import '../../core/providers/database_provider.dart';
import '../../core/theme/nook_tokens.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/database.dart';
import '../../data/repositories/note_repository.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../data/tables/reminders.dart';

/// Management screen listing all active reminders across notes.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key, this.scheduler});

  final ReminderScheduler? scheduler;

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  List<Reminder> _reminders = [];
  bool _loading = true;

  ReminderRepository _repo() => ReminderRepository(
        ref.read(databaseProvider),
        scheduler: widget.scheduler ?? LocalReminderScheduler(),
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reminders = await _repo().allEnabled();
    if (!mounted) return;
    setState(() {
      _reminders = reminders;
      _loading = false;
    });
  }

  Future<void> _deleteReminder(String id) async {
    unawaited(HapticFeedback.lightImpact());
    await _repo().delete(id);
    await _load();
  }

  Future<void> _showAddDialog() async {
    unawaited(HapticFeedback.lightImpact());
    final db = ref.read(databaseProvider);
    final notes = await NoteRepository(db).getAllNotes();
    if (!mounted) return;

    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a note first to attach a reminder.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await showDialog<
        ({
          String noteId,
          String title,
          DateTime fireAt,
          ReminderRepeat repeat
        })>(
      context: context,
      builder: (_) => _AddReminderDialog(notes: notes),
    );

    if (result != null && mounted) {
      final effectiveFireAt = result.fireAt.isAfter(DateTime.now())
          ? result.fireAt
          : DateTime.now().add(const Duration(hours: 1));
      await _repo().create(
        noteId: result.noteId,
        title: result.title.isEmpty ? 'Nook reminder' : result.title,
        fireAt: effectiveFireAt,
        repeat: result.repeat,
      );
      await _load();
    }
  }

  String _repeatLabel(String repeatDb) =>
      switch (ReminderRepeat.fromDb(repeatDb)) {
        ReminderRepeat.none => '',
        ReminderRepeat.daily => 'Daily',
        ReminderRepeat.weekly => 'Weekly',
        ReminderRepeat.monthly => 'Monthly',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text(
          'Reminders',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 22,
            ),
            tooltip: 'Add reminder',
            onPressed: _showAddDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : _reminders.isEmpty
              ? const EmptyState(
                  icon: HugeIcons.strokeRoundedAlarmClock,
                  title: 'No reminders yet',
                  subtitle:
                      'Schedule reminders from any note or tap + to add one.',
                  animate: false,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: scheme.primary,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      DockSafeArea.bottomOf(context) + 24,
                    ),
                    itemCount: _reminders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final r = _reminders[index];
                      final repeatLabel = _repeatLabel(r.repeat);
                      final formattedTime =
                          DateFormat('EEE, MMM d · HH:mm').format(r.fireAt);

                      return Material(
                        color: scheme.surfaceContainerLow,
                        borderRadius: tokens.borderRadiusLg,
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: tokens.borderRadiusLg,
                          ),
                          leading: HugeIcon(
                            icon: HugeIcons.strokeRoundedAlarmClock,
                            size: 22,
                            color: scheme.primary,
                          ),
                          title: Text(
                            r.title.isEmpty ? 'Untitled reminder' : r.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                formattedTime,
                                style: TextStyle(
                                  fontSize: NookTokens.kFontFloor,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              if (repeatLabel.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.secondaryContainer,
                                    borderRadius: tokens.borderRadiusPill,
                                  ),
                                  child: Text(
                                    repeatLabel,
                                    style: TextStyle(
                                      fontSize: NookTokens.kFontFloor,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onTap: () => context.push('/note/${r.noteId}'),
                          trailing: IconButton(
                            icon: HugeIcon(
                              icon: HugeIcons.strokeRoundedDelete01,
                              size: 20,
                              color: scheme.error,
                            ),
                            tooltip: 'Delete reminder',
                            onPressed: () => _deleteReminder(r.id),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _AddReminderDialog extends StatefulWidget {
  const _AddReminderDialog({required this.notes});

  final List<Note> notes;

  @override
  State<_AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<_AddReminderDialog> {
  late Note _selectedNote;
  late final TextEditingController _titleController;
  DateTime _fireAt = DateTime.now().add(const Duration(hours: 1));
  ReminderRepeat _repeat = ReminderRepeat.none;

  @override
  void initState() {
    super.initState();
    _selectedNote = widget.notes.first;
    _titleController = TextEditingController(
      text: _selectedNote.title.isNotEmpty ? _selectedNote.title : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: context.tokens.borderRadiusXl,
      ),
      title: const Text('New Reminder'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Reminder title',
                hintText: 'e.g. Review notes',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedNote.id,
              decoration: const InputDecoration(labelText: 'Note'),
              items: widget.notes
                  .map(
                    (n) => DropdownMenuItem(
                      value: n.id,
                      child: Text(
                        n.title.isEmpty ? 'Untitled' : n.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id == null) return;
                setState(() {
                  _selectedNote = widget.notes.firstWhere((n) => n.id == id);
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ReminderRepeat>(
              initialValue: _repeat,
              decoration: const InputDecoration(labelText: 'Repeat'),
              items: const [
                DropdownMenuItem(
                  value: ReminderRepeat.none,
                  child: Text('Does not repeat'),
                ),
                DropdownMenuItem(
                  value: ReminderRepeat.daily,
                  child: Text('Daily'),
                ),
                DropdownMenuItem(
                  value: ReminderRepeat.weekly,
                  child: Text('Weekly'),
                ),
                DropdownMenuItem(
                  value: ReminderRepeat.monthly,
                  child: Text('Monthly'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _repeat = value);
                }
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedCalendar01,
                size: 18,
                color: scheme.primary,
              ),
              label: Text(
                DateFormat('EEE, MMM d · HH:mm').format(_fireAt),
              ),
              onPressed: () async {
                final now = DateTime.now();
                final date = await showDatePicker(
                  context: context,
                  initialDate: _fireAt.isAfter(now) ? _fireAt : now,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (date == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_fireAt),
                );
                if (time == null) return;
                final candidate = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                if (candidate.isAfter(DateTime.now())) {
                  setState(() => _fireAt = candidate);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (
            noteId: _selectedNote.id,
            title: _titleController.text.trim(),
            fireAt: _fireAt,
            repeat: _repeat,
          )),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

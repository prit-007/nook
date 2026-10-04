import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../data/tables/notes.dart';

/// Callbacks the palette host wires into default commands.
class CommandPaletteActions {
  const CommandPaletteActions({
    required this.onCreateNote,
    required this.onFromTemplate,
    this.onLockNow,
    this.onToggleTheme,
  });

  final void Function(NoteType type) onCreateNote;
  final VoidCallback onFromTemplate;
  final VoidCallback? onLockNow;
  final VoidCallback? onToggleTheme;
}

/// A single command-palette action.
class NookCommand {
  const NookCommand({
    required this.id,
    required this.title,
    required this.keywords,
    required this.icon,
    this.onCreateNoteType,
    this.onRun,
  });

  final String id;
  final String title;
  final String keywords;
  final List<List<dynamic>> icon;
  final NoteType? onCreateNoteType;
  final void Function(BuildContext context)? onRun;

  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = '$title $keywords'.toLowerCase();
    return haystack.contains(q) || fuzzyScore(q, haystack) < 9999;
  }
}

/// Subsequence fuzzy score (lower = better). Returns 9999 when no match.
int fuzzyScore(String query, String target) {
  final q = query.toLowerCase();
  final t = target.toLowerCase();
  if (q.isEmpty) return 0;
  if (t.contains(q)) return t.indexOf(q);
  var ti = 0;
  var score = 0;
  for (var qi = 0; qi < q.length; qi++) {
    final ch = q[qi];
    var found = false;
    while (ti < t.length) {
      if (t[ti] == ch) {
        found = true;
        score += ti;
        ti++;
        break;
      }
      ti++;
      score += 1;
    }
    if (!found) return 9999;
  }
  return score;
}

/// Filters and ranks commands for [query].
List<NookCommand> filterCommands(List<NookCommand> commands, String query) {
  final q = query.trim();
  final scored = <(int, NookCommand)>[];
  for (final c in commands) {
    if (!c.matchesQuery(q)) continue;
    final score = q.isEmpty ? 0 : fuzzyScore(q, '${c.title} ${c.keywords}');
    if (score >= 9999) continue;
    scored.add((score, c));
  }
  scored.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final s in scored) s.$2];
}

/// Builds the default command set bound to [actions].
List<NookCommand> buildDefaultCommands(CommandPaletteActions actions) {
  return [
    const NookCommand(
      id: 'new-note',
      title: 'New note',
      keywords: 'create compose blank text',
      icon: HugeIcons.strokeRoundedPencil,
      onCreateNoteType: NoteType.text,
    ),
    const NookCommand(
      id: 'new-checklist',
      title: 'New checklist',
      keywords: 'tasks todo create',
      icon: HugeIcons.strokeRoundedCheckList,
      onCreateNoteType: NoteType.checklist,
    ),
    const NookCommand(
      id: 'new-doodle',
      title: 'New doodle',
      keywords: 'draw sketch canvas create',
      icon: HugeIcons.strokeRoundedDrawingCompass,
      onCreateNoteType: NoteType.doodle,
    ),
    NookCommand(
      id: 'from-template',
      title: 'New note from template',
      keywords: 'template start reuse',
      icon: HugeIcons.strokeRoundedBook01,
      onRun: (_) => actions.onFromTemplate(),
    ),
    NookCommand(
      id: 'search',
      title: 'Search notes',
      keywords: 'find lookup fts',
      icon: HugeIcons.strokeRoundedSearch01,
      onRun: (context) => context.go('/home/search'),
    ),
    NookCommand(
      id: 'notebooks',
      title: 'Open notebooks',
      keywords: 'collections folders',
      icon: HugeIcons.strokeRoundedFolder01,
      onRun: (context) => context.go('/notebooks'),
    ),
    NookCommand(
      id: 'tags',
      title: 'Open tags',
      keywords: 'labels',
      icon: HugeIcons.strokeRoundedTag01,
      onRun: (context) => context.go('/tags'),
    ),
    NookCommand(
      id: 'trash',
      title: 'Open trash / bin',
      keywords: 'deleted recycle bin',
      icon: HugeIcons.strokeRoundedDelete01,
      onRun: (context) => context.go('/trash'),
    ),
    NookCommand(
      id: 'settings',
      title: 'Open settings',
      keywords: 'preferences config',
      icon: HugeIcons.strokeRoundedConfiguration01,
      onRun: (context) => context.go('/settings'),
    ),
    NookCommand(
      id: 'security',
      title: 'Open security settings',
      keywords: 'lock pin vault biometric',
      icon: HugeIcons.strokeRoundedLock,
      onRun: (context) => context.go('/settings/security'),
    ),
    NookCommand(
      id: 'sync',
      title: 'Open sync',
      keywords: 'pair transfer nearby',
      icon: HugeIcons.strokeRoundedWifi01,
      onRun: (context) => context.go('/sync'),
    ),
    NookCommand(
      id: 'logs',
      title: 'Open app logs',
      keywords: 'debug talker developer',
      icon: HugeIcons.strokeRoundedFile01,
      onRun: (context) => context.go('/settings/logs'),
    ),
    NookCommand(
      id: 'lock-now',
      title: 'Lock app now',
      keywords: 'biometric secure freeze',
      icon: HugeIcons.strokeRoundedFingerPrint,
      onRun: (_) => actions.onLockNow?.call(),
    ),
    NookCommand(
      id: 'toggle-theme',
      title: 'Toggle light / dark theme',
      keywords: 'appearance dark light mode',
      icon: HugeIcons.strokeRoundedMoon01,
      onRun: (_) => actions.onToggleTheme?.call(),
    ),
  ];
}

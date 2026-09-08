import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/talker_provider.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/database.dart';
import '../../data/repositories/note_repository.dart';

/// WhatsApp-style "Locked Chats" gallery — flush, edge-to-edge list
/// with no borders or cards, matching the native messaging app aesthetic.
class LockedNotesScreen extends ConsumerStatefulWidget {
  const LockedNotesScreen({super.key});

  @override
  ConsumerState<LockedNotesScreen> createState() => _LockedNotesScreenState();
}

class _LockedNotesScreenState extends ConsumerState<LockedNotesScreen> {
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final notes = await NoteRepository(db).getLockedNotes();
    nookLog(
      NookLogKey.security,
      'Locked notes viewed: ${notes.length}',
      LogLevel.info,
    );
    if (mounted) {
      setState(() {
        _notes = notes;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverAppBar.large(
                  expandedHeight: 120.0,
                  backgroundColor: scheme.surface,
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                        size: 24,
                        color: scheme.onSurface),
                    onPressed: () => context.pop(),
                  ),
                  flexibleSpace: const FlexibleSpaceBar(
                    titlePadding:
                        EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    title: Text(
                      'Locked Notes',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                  ),
                ),
                if (_notes.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: HugeIcons.strokeRoundedLock,
                      title: 'No secured notes',
                      subtitle: 'Lock notes from the editor options menu',
                      animate: true,
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: _notes.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      indent: 72,
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: HugeIcon(
                              icon: HugeIcons.strokeRoundedLock,
                              color: scheme.primary,
                              size: 24),
                        ),
                        title: Text(
                          note.title.isNotEmpty
                              ? note.title
                              : 'Untitled Document',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Tap to unlock and view',
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 14),
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.push('/note/${note.id}');
                        },
                      );
                    },
                  ),
              ],
            ),
    );
  }
}

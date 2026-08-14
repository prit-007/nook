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

/// Elegant gallery of locked notes using a `SliverAppBar` with
/// macro-typography, matching the rest of the app's editorial layout.
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
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverAppBar.large(
                  expandedHeight: 140.0,
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
                    titlePadding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    title: Text(
                      'Secured Notes',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
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
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    sliver: SliverList.builder(
                      itemCount: _notes.length,
                      itemBuilder: (context, index) {
                        final note = _notes[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  scheme.outlineVariant.withValues(alpha: 0.2),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHigh,
                                shape: BoxShape.circle,
                              ),
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedLock,
                                color: scheme.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              note.title.isNotEmpty
                                  ? note.title
                                  : 'Untitled Document',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Biometric access required',
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                            trailing: HugeIcon(
                              icon: HugeIcons.strokeRoundedArrowRight01,
                              size: 18,
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context.push('/note/${note.id}');
                            },
                          ),
                        );
                      },
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 64)),
              ],
            ),
    );
  }
}

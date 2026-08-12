import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/providers/database_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/masked_reveal.dart';
import '../../core/widgets/masked_reveal_text.dart';
import '../../core/widgets/parallax_card.dart';
import '../../data/database.dart';
import '../../data/repositories/tag_repository.dart';
import '../home/widgets/note_card.dart';

/// Tag detail — notes filtered by tag with a macro-typography SliverAppBar.
class TagDetailScreen extends ConsumerStatefulWidget {
  const TagDetailScreen({super.key, required this.tagId});

  final String tagId;

  @override
  ConsumerState<TagDetailScreen> createState() => _TagDetailScreenState();
}

class _TagDetailScreenState extends ConsumerState<TagDetailScreen> {
  String _tagName = '';
  Color? _tagColor;
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final tagRepo = TagRepository(db);

    final tag = await tagRepo.getTagById(widget.tagId);
    if (tag != null) {
      _tagName = tag.name;
      _tagColor = NookColors.parseHex(tag.colorSeed);
    }

    final results = await tagRepo.getNotesForTag(widget.tagId);

    if (!mounted) return;
    setState(() {
      _notes = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

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
                    icon: Icon(
                      LucideIcons.arrowLeft,
                      color: scheme.onSurface,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_tagColor != null)
                          Icon(
                            LucideIcons.tag,
                            color: _tagColor,
                            size: 20,
                          ),
                        if (_tagColor != null) const SizedBox(width: 8),
                        MaskedRevealText(
                          _tagName.isEmpty ? 'Tag' : _tagName,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: _tagColor ?? scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_notes.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: LucideIcons.fileText,
                      title: 'No notes found',
                      subtitle: 'Tag your notes to see them here',
                      animate: true,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.75,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final card = NoteCard(
                            note: _notes[index],
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context.push('/note/${_notes[index].id}');
                            },
                          );
                          if (reduceMotion) return card;
                          return ParallaxCard(
                            child: MaskedReveal(
                              delay: Duration(
                                milliseconds: (index * 70).clamp(0, 500),
                              ),
                              child: card,
                            ),
                          );
                        },
                        childCount: _notes.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
    );
  }
}

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/adaptive_breakpoints.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/selection_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/dock_safe_area.dart';
import '../../core/widgets/masked_reveal.dart';
import '../../core/widgets/masked_reveal_text.dart';
import '../../data/database.dart';
import '../../data/repositories/tag_repository.dart';
import 'widgets/tag_detail_pane.dart';

/// Tags list screen — tactile color pills with a frosted-glass create sheet.
class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  List<Tag> _tags = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = TagRepository(ref.read(databaseProvider));
    final results = await repo.getAllTags();
    if (!mounted) return;
    setState(() {
      _tags = results;
      _loading = false;
    });
  }

  void _showCreateSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateTagSheet(onCreated: _load),
    );
  }

  void _showDeleteDialog(Tag tag) {
    HapticFeedback.mediumImpact();
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Delete Tag',
            style: TextStyle(
              fontFamily: 'Playfair Display',
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          content: Text(
            'Are you sure you want to delete the "${tag.name}" tag? Notes with '
            'this tag will not be deleted.',
            style: TextStyle(
              fontFamily: 'Inter',
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () async {
                unawaited(HapticFeedback.lightImpact());
                final repo = TagRepository(ref.read(databaseProvider));
                await repo.deleteTag(tag.id);
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDualPane = AdaptiveBreakpoints.supportsDualPane(context);

    final grid = _tagsGrid(scheme, isDualPane);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: MaskedRevealText(
                'Tags',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: scheme.onSurface,
                ),
              ),
              backgroundColor: Colors.transparent,
              centerTitle: false,
            ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : isDualPane
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(
                      flex: 3,
                      child: Container(
                        color:
                            scheme.surfaceContainerLow.withValues(alpha: 0.3),
                        child: grid,
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.15),
                    ),
                    const Flexible(flex: 2, child: TagDetailPane()),
                  ],
                )
              : grid,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: widget.embedded
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: DockSafeArea.bottomOf(context) + 16,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: FloatingActionButton.extended(
                    // Unique hero tag: TagsScreen stays alive next to NotebooksScreen
                    // inside the CollectionsScreen IndexedStack.
                    heroTag: 'fab-tags',
                    backgroundColor:
                        scheme.primaryContainer.withValues(alpha: 0.8),
                    foregroundColor: scheme.onPrimaryContainer,
                    elevation: 0,
                    icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedAdd01,
                        size: 24,
                        color: scheme.onPrimaryContainer),
                    label: const Text(
                      'New Tag',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _showCreateSheet,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _tagsGrid(ColorScheme scheme, bool isDualPane) {
    if (_tags.isEmpty) {
      return const EmptyState(
        icon: HugeIcons.strokeRoundedTags,
        title: 'No tags yet',
        subtitle: 'Organize your vault by creating tags',
        animate: true,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: scheme.primary,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          DockSafeArea.bottomOf(context) + 80,
        ),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: _tags.indexed.map((entry) {
              final (index, tag) = entry;
              final tagColor = NookColors.parseHex(
                tag.colorSeed,
              );
              return MaskedReveal(
                delay: Duration(
                  milliseconds: 150 + (index * 40).clamp(0, 600),
                ),
                child: _TagPill(
                  tag: tag,
                  color: tagColor,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (isDualPane) {
                      ref.read(selectedTagIdProvider.notifier).state = tag.id;
                      return;
                    }
                    context.push('/tags/${tag.id}');
                  },
                  onLongPress: () => _showDeleteDialog(tag),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

String _hexFromColor(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

class _TagPill extends StatefulWidget {
  const _TagPill({
    required this.tag,
    required this.color,
    required this.onTap,
    required this.onLongPress,
  });

  final Tag tag;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  State<_TagPill> createState() => _TagPillState();
}

class _TagPillState extends State<_TagPill> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                  icon: HugeIcons.strokeRoundedTag01,
                  size: 16,
                  color: widget.color),
              const SizedBox(width: 8),
              Text(
                widget.tag.name,
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: widget.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for creating a new tag.
///
/// Owns its [TextEditingController] (disposed with the sheet) so the field's
/// lifetime matches the sheet's route — it is neither leaked nor disposed
/// while the sheet's exit transition is still animating.
class _CreateTagSheet extends ConsumerStatefulWidget {
  const _CreateTagSheet({required this.onCreated});

  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateTagSheet> createState() => _CreateTagSheetState();
}

class _CreateTagSheetState extends ConsumerState<_CreateTagSheet> {
  final _nameController = TextEditingController();
  Color _selectedColor = NookColors.defaultSeed;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _isSelected(Color seed) => seed == _selectedColor;

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) return;
    unawaited(HapticFeedback.lightImpact());
    final repo = TagRepository(ref.read(databaseProvider));
    await repo.createTag(
      name: _nameController.text.trim(),
      colorSeed: _hexFromColor(_selectedColor),
    );
    if (mounted) Navigator.pop(context);
    widget.onCreated();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'New Tag',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: scheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Ideas, Journal, Work',
                      hintStyle: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: scheme.surface.withValues(alpha: 0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'COLOR THEME',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final seed in NookColors.seeds)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedColor = seed);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutBack,
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: seed,
                              shape: BoxShape.circle,
                              boxShadow: _isSelected(seed)
                                  ? [
                                      BoxShadow(
                                        color: seed.withValues(alpha: 0.5),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: _isSelected(seed)
                                ? const HugeIcon(
                                    icon: HugeIcons
                                        .strokeRoundedCheckmarkCircle01,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: _selectedColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _create,
                          child: const Text(
                            'Create Tag',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

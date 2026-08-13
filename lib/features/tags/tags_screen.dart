import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/adaptive_breakpoints.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/selection_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/masked_reveal.dart';
import '../../core/widgets/masked_reveal_text.dart';
import '../../data/database.dart';
import '../../data/repositories/tag_repository.dart';
import 'widgets/tag_detail_pane.dart';

/// Tags list screen — tactile color pills with a frosted-glass create sheet.
class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

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
    final nameController = TextEditingController();
    String selectedColor = '#2196F3';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final scheme = Theme.of(context).colorScheme;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New Tag',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: nameController,
                          autofocus: true,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Ideas, Journal, Work',
                            filled: true,
                            fillColor: scheme.surface.withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'COLOR THEME',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            '#2196F3',
                            '#4CAF50',
                            '#FF9800',
                            '#E91E63',
                            '#9C27B0',
                            '#00BCD4',
                            '#607D8B',
                            '#795548',
                          ].map((c) {
                            final color = NookColors.parseHex(c);
                            final isSelected = selectedColor == c;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setModalState(() => selectedColor = c);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? scheme.onSurface
                                        : Colors.transparent,
                                    width: isSelected ? 3 : 0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: color.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: () async {
                                  if (nameController.text.trim().isEmpty) {
                                    return;
                                  }
                                  unawaited(HapticFeedback.lightImpact());
                                  final repo = TagRepository(
                                    ref.read(databaseProvider),
                                  );
                                  await repo.createTag(
                                    name: nameController.text.trim(),
                                    colorSeed: selectedColor,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _load();
                                },
                                child: const Text(
                                  'Save Tag',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
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
        },
      ),
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
          backgroundColor: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Delete Tag',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          content: Text(
            'Are you sure you want to delete the "${tag.name}" tag? Notes with '
            'this tag will not be deleted.',
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
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
      appBar: AppBar(
        title: const MaskedRevealText(
          'Tags',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: scheme.primary))
          : isDualPane
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Flexible(flex: 3, child: grid),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                    const Flexible(flex: 2, child: TagDetailPane()),
                  ],
                )
              : grid,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: FloatingActionButton.extended(
              backgroundColor: scheme.primary.withValues(alpha: 0.9),
              foregroundColor: scheme.onPrimary,
              elevation: 0,
              icon: const Icon(LucideIcons.plus),
              label: const Text(
                'New Tag',
                style: TextStyle(fontWeight: FontWeight.w700),
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
        icon: LucideIcons.tags,
        title: 'No tags yet',
        subtitle: 'Organize your vault by creating tags',
        animate: true,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
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
                  milliseconds: 150 + (index * 60).clamp(0, 600),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.tag, size: 16, color: widget.color),
              const SizedBox(width: 8),
              Text(
                widget.tag.name,
                style: TextStyle(
                  color: widget.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

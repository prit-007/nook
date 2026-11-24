import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../core/theme/nook_tokens.dart';
import '../models/home_view_mode.dart';

/// Modal bottom sheet for configuring layout view mode and grouping.
class HomeViewOptionsSheet extends StatefulWidget {
  const HomeViewOptionsSheet({
    super.key,
    required this.currentViewMode,
    required this.currentGroupBy,
    required this.onViewModeChanged,
    required this.onGroupByChanged,
  });

  final HomeViewMode currentViewMode;
  final HomeGroupBy currentGroupBy;
  final ValueChanged<HomeViewMode> onViewModeChanged;
  final ValueChanged<HomeGroupBy> onGroupByChanged;

  static Future<void> show(
    BuildContext context, {
    required HomeViewMode currentViewMode,
    required HomeGroupBy currentGroupBy,
    required ValueChanged<HomeViewMode> onViewModeChanged,
    required ValueChanged<HomeGroupBy> onGroupByChanged,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomeViewOptionsSheet(
        currentViewMode: currentViewMode,
        currentGroupBy: currentGroupBy,
        onViewModeChanged: onViewModeChanged,
        onGroupByChanged: onGroupByChanged,
      ),
    );
  }

  @override
  State<HomeViewOptionsSheet> createState() => _HomeViewOptionsSheetState();
}

class _HomeViewOptionsSheetState extends State<HomeViewOptionsSheet> {
  late HomeViewMode _viewMode;
  late HomeGroupBy _groupBy;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.currentViewMode;
    _groupBy = widget.currentGroupBy;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: context.tokens.borderRadiusXl,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: context.tokens.borderRadiusXl,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: SingleChildScrollView(
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
                  const SizedBox(height: 20),
                  Text(
                    'View options',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Layout mode',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<HomeViewMode>(
                      segments: const [
                        ButtonSegment(
                          value: HomeViewMode.masonry,
                          label: Text('Masonry'),
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedGridView,
                            size: 18,
                          ),
                        ),
                        ButtonSegment(
                          value: HomeViewMode.list,
                          label: Text('List'),
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedListView,
                            size: 18,
                          ),
                        ),
                        ButtonSegment(
                          value: HomeViewMode.compact,
                          label: Text('Compact'),
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedMenu01,
                            size: 18,
                          ),
                        ),
                      ],
                      selected: {_viewMode},
                      onSelectionChanged: (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _viewMode = val.first);
                        widget.onViewModeChanged(val.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Group by',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<HomeGroupBy>(
                      segments: const [
                        ButtonSegment(
                          value: HomeGroupBy.none,
                          label: Text('None'),
                        ),
                        ButtonSegment(
                          value: HomeGroupBy.pinned,
                          label: Text('Pinned'),
                        ),
                        ButtonSegment(
                          value: HomeGroupBy.date,
                          label: Text('Date'),
                        ),
                      ],
                      selected: {_groupBy},
                      onSelectionChanged: (val) {
                        HapticFeedback.selectionClick();
                        setState(() => _groupBy = val.first);
                        widget.onGroupByChanged(val.first);
                      },
                    ),
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

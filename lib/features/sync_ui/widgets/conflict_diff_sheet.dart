import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../core/diff/text_differ.dart';

/// Shows an interactive bottom sheet to inspect changes and resolve a sync conflict.
Future<String?> showConflictDiffSheet(
  BuildContext context, {
  required String noteTitle,
  required String localDeviceName,
  required String remoteDeviceName,
  required String localText,
  required String remoteText,
  DateTime? localUpdatedAt,
  DateTime? remoteUpdatedAt,
  void Function(String choice)? onResolved,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ConflictDiffSheet(
      noteTitle: noteTitle,
      localDeviceName: localDeviceName,
      remoteDeviceName: remoteDeviceName,
      localText: localText,
      remoteText: remoteText,
      localUpdatedAt: localUpdatedAt,
      remoteUpdatedAt: remoteUpdatedAt,
      onResolved: onResolved,
    ),
  );
}

/// Visual difference inspector between a local note and incoming remote note.
class ConflictDiffSheet extends StatefulWidget {
  const ConflictDiffSheet({
    super.key,
    required this.noteTitle,
    required this.localDeviceName,
    required this.remoteDeviceName,
    required this.localText,
    required this.remoteText,
    this.localUpdatedAt,
    this.remoteUpdatedAt,
    this.onResolved,
  });

  final String noteTitle;
  final String localDeviceName;
  final String remoteDeviceName;
  final String localText;
  final String remoteText;
  final DateTime? localUpdatedAt;
  final DateTime? remoteUpdatedAt;
  final void Function(String choice)? onResolved;

  @override
  State<ConflictDiffSheet> createState() => _ConflictDiffSheetState();
}

class _ConflictDiffSheetState extends State<ConflictDiffSheet> {
  int _selectedView = 0; // 0 = Changes, 1 = Side by Side
  late DiffResult _diff;

  @override
  void initState() {
    super.initState();
    _diff = TextDiffer.diffLines(widget.localText, widget.remoteText);
  }

  void _choose(String choice) {
    if (widget.onResolved != null) {
      widget.onResolved!(choice);
    }
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAlertCircle,
                  color: scheme.error,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.noteTitle,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.localDeviceName} vs ${widget.remoteDeviceName}',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Additions badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x224CAF50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${_diff.additions}',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Deletions badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x22F44336),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '-${_diff.deletions}',
                    style: const TextStyle(
                      color: Color(0xFFC62828),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // View Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Changes'),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedGitFork,
                    size: 16,
                  ),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Side by Side'),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedView,
                    size: 16,
                  ),
                ),
              ],
              selected: {_selectedView},
              onSelectionChanged: (selected) {
                setState(() => _selectedView = selected.first);
              },
            ),
          ),

          const Divider(height: 16),

          // Content body
          Expanded(
            child: _selectedView == 0
                ? _buildUnifiedDiff(context, scheme)
                : _buildSideBySide(context, scheme),
          ),

          const Divider(height: 1),

          // Actions
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => _choose('local'),
                          child: const Text(
                            'Keep this device',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => _choose('remote'),
                          child: const Text(
                            'Keep incoming',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _choose('both'),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCopyPlus,
                      size: 16,
                      color: scheme.primary,
                    ),
                    label: const Text(
                      'Keep both',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedDiff(BuildContext context, ColorScheme scheme) {
    if (_diff.segments.isEmpty) {
      return Center(
        child: Text(
          'No textual differences.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _diff.segments.length,
      itemBuilder: (context, index) {
        final segment = _diff.segments[index];
        Color? bgColor;
        Color textColor = scheme.onSurface;
        String prefix = ' ';

        switch (segment.type) {
          case DiffType.inserted:
            bgColor = const Color(0x1E4CAF50);
            textColor = const Color(0xFF2E7D32);
            prefix = '+';
            break;
          case DiffType.deleted:
            bgColor = const Color(0x1EF44336);
            textColor = const Color(0xFFC62828);
            prefix = '-';
            break;
          case DiffType.unchanged:
            bgColor = Colors.transparent;
            prefix = ' ';
            break;
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  prefix,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  segment.text.isEmpty ? ' ' : segment.text,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: textColor,
                    fontSize: 12,
                    decoration: segment.type == DiffType.deleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSideBySide(BuildContext context, ColorScheme scheme) {
    final localDate = widget.localUpdatedAt != null
        ? DateFormat.yMMMd().add_jm().format(widget.localUpdatedAt!)
        : null;
    final remoteDate = widget.remoteUpdatedAt != null
        ? DateFormat.yMMMd().add_jm().format(widget.remoteUpdatedAt!)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Local pane
          Expanded(
            child: _buildVersionCard(
              title: widget.localDeviceName,
              subtitle: 'This device',
              date: localDate,
              text: widget.localText,
              scheme: scheme,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          // Remote pane
          Expanded(
            child: _buildVersionCard(
              title: widget.remoteDeviceName,
              subtitle: 'Incoming',
              date: remoteDate,
              text: widget.remoteText,
              scheme: scheme,
              color: scheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard({
    required String title,
    required String subtitle,
    required String? date,
    required String text,
    required ColorScheme scheme,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (date != null) ...[
            const SizedBox(height: 2),
            Text(
              date,
              style: TextStyle(
                fontSize: 10,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
          const Divider(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                text.isEmpty ? '(Empty)' : text,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

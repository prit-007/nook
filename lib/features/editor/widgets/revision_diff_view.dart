import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../core/diff/text_differ.dart';

/// Interactive visual diff and snapshot inspector for a note revision.
class RevisionDiffView extends StatefulWidget {
  const RevisionDiffView({
    super.key,
    required this.revisionTitle,
    required this.currentTitle,
    required this.revisionText,
    required this.currentText,
    required this.revisionDate,
    required this.onRestore,
  });

  final String revisionTitle;
  final String currentTitle;
  final String revisionText;
  final String currentText;
  final DateTime revisionDate;
  final VoidCallback onRestore;

  @override
  State<RevisionDiffView> createState() => _RevisionDiffViewState();
}

class _RevisionDiffViewState extends State<RevisionDiffView> {
  bool _showSnapshot = false;
  late DiffResult _diff;

  @override
  void initState() {
    super.initState();
    _recomputeDiff();
  }

  @override
  void didUpdateWidget(covariant RevisionDiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revisionText != widget.revisionText ||
        oldWidget.currentText != widget.currentText) {
      _recomputeDiff();
    }
  }

  void _recomputeDiff() {
    _diff = TextDiffer.diffLines(widget.revisionText, widget.currentText);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateStr = DateFormat('MMM d, y · h:mm a').format(widget.revisionDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedClock01,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                  ),
                  const Spacer(),
                  // Additions & deletions badge
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
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Revision: ${widget.revisionTitle.isEmpty ? "Untitled" : widget.revisionTitle}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              if (widget.currentTitle != widget.revisionTitle) ...[
                const SizedBox(height: 2),
                Text(
                  'Current note title: ${widget.currentTitle.isEmpty ? "Untitled" : widget.currentTitle}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Mode switch tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('Diff View'),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('Full Snapshot'),
              ),
            ],
            selected: {_showSnapshot},
            onSelectionChanged: (selection) {
              setState(() {
                _showSnapshot = selection.first;
              });
            },
          ),
        ),

        const SizedBox(height: 8),

        // Body content
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant.withAlpha(80)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _showSnapshot ? _buildSnapshotView() : _buildDiffView(),
            ),
          ),
        ),

        // Footer action bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: FilledButton.icon(
            onPressed: widget.onRestore,
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowTurnBackward,
              size: 18,
            ),
            label: const Text('Restore this version'),
          ),
        ),
      ],
    );
  }

  Widget _buildSnapshotView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        widget.revisionText.isEmpty ? 'Empty revision' : widget.revisionText,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildDiffView() {
    if (_diff.segments.isEmpty) {
      return const Center(
        child: Text('No changes between this revision and current note.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _diff.segments.length,
      itemBuilder: (context, index) {
        final seg = _diff.segments[index];
        final isInserted = seg.type == DiffType.inserted;
        final isDeleted = seg.type == DiffType.deleted;

        Color? bgColor;
        Color? textColor;
        String prefix = ' ';

        if (isInserted) {
          bgColor = const Color(0x1E4CAF50);
          textColor = const Color(0xFF2E7D32);
          prefix = '+';
        } else if (isDeleted) {
          bgColor = const Color(0x1EF44336);
          textColor = const Color(0xFFC62828);
          prefix = '-';
        }

        return Container(
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  prefix,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  seg.text,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: textColor,
                    fontSize: 13,
                    decoration: isDeleted ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

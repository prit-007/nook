import 'package:flutter/material.dart';

import '../../../data/database.dart';

/// Displays a single notebook as a card with color, icon, and name.
class NotebookCard extends StatelessWidget {
  const NotebookCard({super.key, required this.notebook});

  final Notebook notebook;

  Color get _seedColor {
    return Color(
      int.parse('FF${notebook.colorSeed.replaceFirst('#', '')}', radix: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardColor =
        ColorScheme.fromSeed(seedColor: _seedColor).surfaceContainerLow;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _seedColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.book,
              color: _seedColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            notebook.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: scheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

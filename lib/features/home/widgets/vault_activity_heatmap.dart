import 'package:flutter/material.dart';

import '../../../core/theme/nook_tokens.dart';

/// Local-only 12-week (84-day) writing cadence heatmap computed from note
/// timestamps.
class VaultActivityHeatmap extends StatelessWidget {
  const VaultActivityHeatmap({
    super.key,
    required this.activityDates,
    this.weeks = 12,
    this.referenceDate,
  });

  final List<DateTime> activityDates;
  final int weeks;
  final DateTime? referenceDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = referenceDate ?? DateTime.now();
    final normalizedToday = DateTime.utc(today.year, today.month, today.day);
    final totalDays = weeks * 7;

    final countsByDay = <DateTime, int>{};
    for (final d in activityDates) {
      final day = DateTime.utc(d.year, d.month, d.day);
      countsByDay[day] = (countsByDay[day] ?? 0) + 1;
    }

    final activeDaysInWindow = List<DateTime>.generate(
      totalDays,
      (i) => normalizedToday.subtract(Duration(days: totalDays - 1 - i)),
    );
    final activeCount =
        activeDaysInWindow.where((day) => (countsByDay[day] ?? 0) > 0).length;

    return Container(
      padding: const EdgeInsets.all(NookTokens.kSpacingLg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(NookTokens.kRadiusMd),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vault Cadence',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                '$activeCount active day${activeCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: NookTokens.kFontFloor,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: NookTokens.kSpacingMd),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var w = 0; w < weeks; w++) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var d = 0; d < 7; d++) ...[
                      Builder(
                        builder: (context) {
                          final idx = w * 7 + d;
                          final day = activeDaysInWindow[idx];
                          final count = countsByDay[day] ?? 0;
                          final cellColor = _cellColor(scheme, count);
                          final label =
                              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}: $count edit${count == 1 ? '' : 's'}';
                          return Tooltip(
                            message: label,
                            child: Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: cellColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _cellColor(ColorScheme scheme, int count) {
    if (count <= 0) {
      return scheme.surfaceContainerHighest.withValues(alpha: 0.5);
    }
    if (count == 1) {
      return scheme.primary.withValues(alpha: 0.35);
    }
    if (count == 2) {
      return scheme.primary.withValues(alpha: 0.65);
    }
    return scheme.primary;
  }
}

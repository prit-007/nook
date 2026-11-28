import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/trash_auto_purger.dart';

/// Allowed Bin retention windows in days. `0` disables automatic purging.
const List<int> kTrashRetentionOptions = [7, 14, 30, 60, 90, 0];

/// Persisted user preference for how long soft-deleted items remain in Bin.
class TrashRetentionPreference extends ChangeNotifier {
  TrashRetentionPreference({int days = kTrashRetentionDays}) : _days = days;

  static const String _prefKey = 'trash_retention_days';

  int _days;

  /// Number of days before soft-deleted items are purged, or `0` for never.
  int get days => _days;

  /// Human-readable label for the active retention window.
  String get label => _days <= 0 ? 'Never (keep indefinitely)' : '$_days days';

  /// Updates the retention window and persists it to [SharedPreferences].
  Future<void> setDays(int value) async {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'must be >= 0');
    }
    if (_days == value) return;
    _days = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, value);
  }

  /// Loads the persisted retention preference (defaulting to 30 days).
  static Future<TrashRetentionPreference> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_prefKey) ?? kTrashRetentionDays;
    return TrashRetentionPreference(
        days: saved < 0 ? kTrashRetentionDays : saved);
  }
}

final trashRetentionProvider = ChangeNotifierProvider<TrashRetentionPreference>(
  (ref) => TrashRetentionPreference(),
);

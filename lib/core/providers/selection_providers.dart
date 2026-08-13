import 'package:flutter_riverpod/legacy.dart';

/// Holds the currently selected note in the master-detail (tablet) layout.
///
/// On compact screens navigation happens via route push and this value stays
/// null; on expanded (dual-pane) screens HomeScreen writes to it and the
/// right-hand editor pane reads it.
final selectedNoteIdProvider = StateProvider<String?>((ref) => null);

/// Holds the currently selected notebook in the notebooks master-detail view.
final selectedNotebookIdProvider = StateProvider<String?>((ref) => null);

/// Holds the currently selected tag in the tags master-detail view.
final selectedTagIdProvider = StateProvider<String?>((ref) => null);

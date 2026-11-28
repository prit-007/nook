# Phase 5 — Feature Behaviour Matrix

All Phase 5 features remain 100% offline-first, local-only (zero telemetry, zero network), and respect Nook's locked-note privacy boundary.

| Feature | Entry Point | Locked-Note Boundary | Test Coverage |
|---|---|---|---|
| Structured search filters (`tag:`, `in:`, `is:`, `before:`, `after:`) | `SearchRepository.searchNotesWithFilters` | Excluded unless `includeLocked: true` | `test/data/search_filters_test.dart` |
| Cross-note open checklists view | `ChecklistItemRepository.getOpenTasksAcrossNotes` | Excluded unless `includeLocked: true` | `test/data/cross_note_tasks_test.dart` |
| Editable Doodle SVG export | `DoodleStrokesCodec.toSvg` | N/A (operates on explicit in-memory strokes) | `test/features/doodle/doodle_svg_export_test.dart` |
| Unlinked mentions discovery | `NoteLinkRepository.findUnlinkedMentions` | Excluded unless `includeLocked: true` | `test/data/unlinked_mentions_test.dart` |

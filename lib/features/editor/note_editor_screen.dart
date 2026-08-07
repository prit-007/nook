import 'package:flutter/material.dart';

/// Note editor screen — AppFlowy Editor integration.
/// Full implementation in Phase 1.
class NoteEditorScreen extends StatelessWidget {
  const NoteEditorScreen({
    super.key,
    this.noteId,
    this.notebookId,
    this.type,
  });

  final String? noteId;
  final String? notebookId;
  final String? type;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(noteId != null ? 'Edit Note' : 'New Note'),
      ),
      body: Center(
        child: Text(
          noteId != null ? 'Edit Note $noteId (Phase 1)' : 'New Note (Phase 1)',
        ),
      ),
    );
  }
}

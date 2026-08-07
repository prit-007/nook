import 'package:flutter/material.dart';

/// Full-screen doodle canvas.
/// Full implementation in Phase 2.
class DoodleCanvasScreen extends StatelessWidget {
  const DoodleCanvasScreen({
    super.key,
    required this.noteId,
    required this.attachmentId,
  });

  final String noteId;
  final String attachmentId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doodle'),
      ),
      body: const Center(
        child: Text('Doodle Canvas (Phase 2)'),
      ),
    );
  }
}

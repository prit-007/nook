import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// In-memory note representation for the read/export-only Web companion.
class WebCompanionNote {
  const WebCompanionNote({
    required this.id,
    required this.title,
    required this.body,
    this.sourceName,
  });

  final String id;
  final String title;
  final String body;
  final String? sourceName;
}

/// Parses `.md`, `.txt`, `.json`, or `.zip` export bytes into
/// [WebCompanionNote] items (pure Dart, zero `dart:io`).
List<WebCompanionNote> parseWebCompanionFiles(
  List<({String name, Uint8List bytes})> files,
) {
  final notes = <WebCompanionNote>[];
  var index = 0;

  for (final file in files) {
    final lower = file.name.toLowerCase();
    if (lower.endsWith('.zip')) {
      try {
        final archive = ZipDecoder().decodeBytes(file.bytes);
        for (final entry in archive.files) {
          if (!entry.isFile) continue;
          final entryLower = entry.name.toLowerCase();
          if (entryLower.endsWith('.md') || entryLower.endsWith('.txt')) {
            final text =
                utf8.decode(entry.content as List<int>, allowMalformed: true);
            final title = _inferTitle(entry.name, text);
            notes.add(WebCompanionNote(
              id: 'web-${++index}',
              title: title,
              body: text,
              sourceName: entry.name,
            ));
          }
        }
      } catch (_) {
        // Ignore corrupt archives cleanly.
      }
      continue;
    }

    if (lower.endsWith('.json') || lower.endsWith('.nook')) {
      try {
        final decoded = jsonDecode(utf8.decode(file.bytes));
        if (decoded is Map && decoded['notes'] is List) {
          for (final item in decoded['notes'] as List) {
            if (item is! Map) continue;
            final title = (item['title'] as String?)?.trim() ?? 'Untitled';
            final body = (item['plainText'] as String?) ?? '';
            notes.add(WebCompanionNote(
              id: (item['id'] as String?) ?? 'web-${++index}',
              title: title.isEmpty ? 'Untitled' : title,
              body: body,
              sourceName: file.name,
            ));
          }
        }
      } catch (_) {
        // Ignore invalid JSON.
      }
      continue;
    }

    final text = utf8.decode(file.bytes, allowMalformed: true);
    notes.add(WebCompanionNote(
      id: 'web-${++index}',
      title: _inferTitle(file.name, text),
      body: text,
      sourceName: file.name,
    ));
  }

  return notes;
}

String _inferTitle(String filename, String text) {
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('# ')) {
      return trimmed.substring(2).trim();
    }
    return trimmed.length > 60 ? trimmed.substring(0, 60) : trimmed;
  }
  return filename;
}

/// Pure-Dart read & export-only companion app for Flutter Web.
class WebCompanionApp extends StatelessWidget {
  const WebCompanionApp({super.key, this.initialNotes = const []});

  final List<WebCompanionNote> initialNotes;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF4A6B5D));
    return MaterialApp(
      title: 'Nook Web Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      home: _WebCompanionHome(initialNotes: initialNotes),
    );
  }
}

class _WebCompanionHome extends StatefulWidget {
  const _WebCompanionHome({required this.initialNotes});

  final List<WebCompanionNote> initialNotes;

  @override
  State<_WebCompanionHome> createState() => _WebCompanionHomeState();
}

class _WebCompanionHomeState extends State<_WebCompanionHome> {
  late List<WebCompanionNote> _notes;
  WebCompanionNote? _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _notes = List.of(widget.initialNotes);
    _selected = _notes.firstOrNull;
  }

  Future<void> _openFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['md', 'txt', 'zip', 'json', 'nook'],
    );
    if (result == null || !mounted) return;
    final loaded = parseWebCompanionFiles([
      for (final f in result.files)
        if (f.bytes != null) (name: f.name, bytes: f.bytes!),
    ]);
    setState(() {
      _notes = [...loaded, ..._notes];
      _selected ??= _notes.firstOrNull;
    });
  }

  Future<void> _copyMarkdown(WebCompanionNote note) async {
    await Clipboard.setData(ClipboardData(text: note.body));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied note content to clipboard')),
    );
  }

  Future<void> _exportPdfPreview(WebCompanionNote note) async {
    final doc = pw.Document(title: note.title);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            note.title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text(note.body, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
    final bytes = await doc.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Prepared PDF (${bytes.length} bytes) for "${note.title}"'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _query.trim().isEmpty
        ? _notes
        : _notes.where((n) {
            final q = _query.toLowerCase();
            return n.title.toLowerCase().contains(q) ||
                n.body.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nook · Read & Export Companion'),
        actions: [
          FilledButton.icon(
            onPressed: _openFiles,
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedFolderOpen,
              size: 18,
            ),
            label: const Text('Open Export / .md'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _notes.isEmpty
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedBookOpen01,
                        size: 48,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Read & Export-Only Web Companion',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Open a Nook .zip export, .nook JSON backup, or .md '
                        'files locally in your browser. Nothing leaves your device.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _openFiles,
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedUpload01,
                          size: 18,
                        ),
                        label: const Text('Load local notes'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Row(
              children: [
                SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Filter loaded notes…',
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(12),
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedSearch01,
                                size: 18,
                              ),
                            ),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final note = filtered[i];
                            return ListTile(
                              selected: _selected?.id == note.id,
                              title: Text(
                                note.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: note.sourceName == null
                                  ? null
                                  : Text(
                                      note.sourceName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: () => setState(() => _selected = note),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _selected == null
                      ? const Center(child: Text('Select a note to read'))
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selected!.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _copyMarkdown(_selected!),
                                    icon: const HugeIcon(
                                      icon: HugeIcons.strokeRoundedCopy01,
                                      size: 16,
                                    ),
                                    label: const Text('Copy'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.tonalIcon(
                                    onPressed: () =>
                                        _exportPdfPreview(_selected!),
                                    icon: const HugeIcon(
                                      icon: HugeIcons.strokeRoundedPdf01,
                                      size: 16,
                                    ),
                                    label: const Text('PDF'),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: SelectableText(_selected!.body),
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
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../data/database.dart';
import '../../../data/tables/attachments.dart';
import '../../../data/tables/notes.dart';
import 'bulk_export.dart';

/// Sanitizes text for built-in PDF Type1 fonts (Helvetica/Courier), replacing
/// unsupported non-Latin1 characters (e.g. emojis) so PDF generation never fails.
String _pdfSafe(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    if (rune == 0x09 || rune == 0x0A || (rune >= 0x20 && rune <= 0xFF)) {
      out.writeCharCode(rune);
    } else if (rune == 0x2018 || rune == 0x2019) {
      out.write("'");
    } else if (rune == 0x201C || rune == 0x201D) {
      out.write('"');
    } else if (rune == 0x2013 || rune == 0x2014) {
      out.write('-');
    } else if (rune == 0x2022 || rune == 0x00B7) {
      out.write('*');
    } else if (rune == 0x2026) {
      out.write('...');
    } else {
      out.write('?');
    }
  }
  return out.toString();
}

String _extractDeltaPlain(dynamic delta) {
  if (delta is! List) return '';
  final buf = StringBuffer();
  for (final op in delta) {
    if (op is Map && op['insert'] is String) {
      buf.write(op['insert'] as String);
    }
  }
  return buf.toString();
}

/// Renders a [Note] (text, checklist, images, doodle thumbnails) to PDF bytes.
Future<Uint8List> renderNotePdf(
  Note note,
  List<ChecklistItem> checklistItems, {
  List<ExportAttachment> attachments = const [],
}) async {
  final doc = pw.Document(
    title: _pdfSafe(note.title.isEmpty ? 'Untitled' : note.title),
    author: 'Nook',
  );

  final byId = <String, ExportAttachment>{
    for (final a in attachments) a.attachment.id: a,
  };
  final renderedIds = <String>{};
  final widgets = <pw.Widget>[];

  final titleText = _pdfSafe(note.title.isEmpty ? 'Untitled' : note.title);
  widgets.add(
    pw.Text(
      titleText,
      style: pw.TextStyle(
        fontSize: 22,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
  widgets.add(pw.SizedBox(height: 4));
  widgets.add(
    pw.Text(
      'Exported from Nook · local-first notes',
      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
    ),
  );
  widgets.add(pw.Divider(color: PdfColors.grey300));
  widgets.add(pw.SizedBox(height: 8));

  if (note.type == NoteType.checklist) {
    final sorted = List<ChecklistItem>.from(checklistItems)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final item in sorted) {
      final mark = item.checked ? '[x]' : '[ ]';
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(
            _pdfSafe('$mark ${item.itemText}'),
            style: pw.TextStyle(
              fontSize: 12,
              decoration: item.checked ? pw.TextDecoration.lineThrough : null,
              color: item.checked ? PdfColors.grey600 : PdfColors.black,
            ),
          ),
        ),
      );
    }
  } else if (note.deltaContent != null && note.deltaContent!.isNotEmpty) {
    try {
      final decoded = jsonDecode(note.deltaContent!);
      final root = decoded is Map ? decoded['document'] : null;
      final children = root is Map ? root['children'] : null;
      if (children is List) {
        for (final node in children) {
          if (node is! Map) continue;
          _appendNodeWidgets(node, widgets, byId, renderedIds);
        }
      }
    } catch (_) {
      final fallback = note.plainText ?? note.deltaContent ?? '';
      widgets.add(pw.Text(_pdfSafe(fallback)));
    }
  } else if (note.plainText != null && note.plainText!.isNotEmpty) {
    widgets.add(pw.Text(_pdfSafe(note.plainText!)));
  }

  for (final att in attachments) {
    if (renderedIds.contains(att.attachment.id)) continue;
    _appendAttachmentWidget(att, widgets);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount} · Nook',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
        ),
      ),
      build: (_) => widgets,
    ),
  );

  return doc.save();
}

void _appendNodeWidgets(
  Map<dynamic, dynamic> node,
  List<pw.Widget> widgets,
  Map<String, ExportAttachment> byId,
  Set<String> renderedIds,
) {
  final type = node['type'] as String? ?? 'paragraph';
  final data = (node['data'] as Map?) ?? const {};
  final text = _pdfSafe(_extractDeltaPlain(data['delta']));

  switch (type) {
    case 'heading':
      final level = (data['level'] as int?) ?? 1;
      final size = level == 1 ? 18.0 : (level == 2 ? 15.0 : 13.0);
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
          child: pw.Text(
            text,
            style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold),
          ),
        ),
      );
    case 'bulleted_list':
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, bottom: 3),
          child: pw.Text('* $text', style: const pw.TextStyle(fontSize: 12)),
        ),
      );
    case 'numbered_list':
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 12, bottom: 3),
          child: pw.Text('- $text', style: const pw.TextStyle(fontSize: 12)),
        ),
      );
    case 'todo_list':
      final checked = data['checked'] == true;
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8, bottom: 3),
          child: pw.Text(
            '${checked ? '[x]' : '[ ]'} $text',
            style: pw.TextStyle(
              fontSize: 12,
              decoration: checked ? pw.TextDecoration.lineThrough : null,
            ),
          ),
        ),
      );
    case 'quote':
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 4),
          padding: const pw.EdgeInsets.only(left: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: PdfColors.grey400, width: 2),
            ),
          ),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 12,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey700,
            ),
          ),
        ),
      );
    case 'code':
      widgets.add(
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.symmetric(vertical: 4),
          padding: const pw.EdgeInsets.all(8),
          color: PdfColors.grey100,
          child: pw.Text(
            text,
            style: pw.TextStyle(font: pw.Font.courier(), fontSize: 10),
          ),
        ),
      );
    case 'divider':
      widgets.add(pw.Divider(color: PdfColors.grey300));
    case 'doodle':
    case 'image':
      final attId = data['attachmentId'] as String?;
      if (attId != null && byId.containsKey(attId)) {
        renderedIds.add(attId);
        _appendAttachmentWidget(byId[attId]!, widgets);
      } else {
        widgets.add(
          pw.Text(
            '[$type attachment]',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
          ),
        );
      }
    default:
      if (text.isNotEmpty) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Text(text, style: const pw.TextStyle(fontSize: 12)),
          ),
        );
      } else {
        widgets.add(pw.SizedBox(height: 6));
      }
  }
}

void _appendAttachmentWidget(
  ExportAttachment att,
  List<pw.Widget> widgets,
) {
  final imageBytes = att.attachment.type == AttachmentType.doodleLayer
      ? att.thumbnailBytes
      : att.bytes;
  if (imageBytes == null || imageBytes.isEmpty) return;

  try {
    final image = pw.MemoryImage(imageBytes);
    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.ConstrainedBox(
          constraints: const pw.BoxConstraints(maxHeight: 280),
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
  } catch (_) {
    widgets.add(
      pw.Text(
        '[attachment: ${_pdfSafe(att.archiveName)}]',
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
      ),
    );
  }
}

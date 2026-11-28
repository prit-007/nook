/// Metadata describing how a note block type participates across rendering,
/// export, full-text search indexing, and peer sync.
class BlockDefinition {
  const BlockDefinition({
    required this.type,
    required this.label,
    required this.supportsRender,
    required this.supportsMarkdownExport,
    required this.supportsHtmlExport,
    required this.supportsSearchIndex,
    required this.supportsSync,
  });

  final String type;
  final String label;
  final bool supportsRender;
  final bool supportsMarkdownExport;
  final bool supportsHtmlExport;
  final bool supportsSearchIndex;
  final bool supportsSync;
}

/// Central registry of all editor block types supported by Nook.
///
/// Ensures every block type has explicit capabilities across render, export,
/// search indexing, and sync rather than ad-hoc switch statements drifting.
class BlockRegistry {
  const BlockRegistry._();

  static const List<BlockDefinition> definitions = [
    BlockDefinition(
      type: 'paragraph',
      label: 'Paragraph',
      supportsRender: true,
      supportsMarkdownExport: true,
      supportsHtmlExport: true,
      supportsSearchIndex: true,
      supportsSync: true,
    ),
    BlockDefinition(
      type: 'heading',
      label: 'Heading',
      supportsRender: true,
      supportsMarkdownExport: true,
      supportsHtmlExport: true,
      supportsSearchIndex: true,
      supportsSync: true,
    ),
    BlockDefinition(
      type: 'bulleted_list',
      label: 'Bulleted List',
      supportsRender: true,
      supportsMarkdownExport: true,
      supportsHtmlExport: true,
      supportsSearchIndex: true,
      supportsSync: true,
    ),
    BlockDefinition(
      type: 'numbered_list',
      label: 'Numbered List',
      supportsRender: true,
      supportsMarkdownExport: true,
      supportsHtmlExport: true,
      supportsSearchIndex: true,
      supportsSync: true,
    ),
    BlockDefinition(
      type: 'todo_list',
      label: 'To-do',
      supportsRender: true,
      supportsMarkdownExport: true,
      supportsHtmlExport: true,
      supportsSearchIndex: true,
      supportsSync: true,
    ),
    BlockDefinition(
      type: 'quote',
      label: 'Quote',
      supportsRender: true,
      supportsMarkdownExport: true,
      supportsHtmlExport: true,
      supportsSearchIndex: true,
      supportsSync: true,
    ),
    BlockDefinition(
      type: 'code',
      label: 'Code',
      supportsRender: true,
      supportsMarkdownExport: true,
      supportsHtmlExport: true,
      supportsSearchIndex: true,
      supportsSync: true,
    ),
    BlockDefinition(
      type: 'callout',
      label: 'Callout',
      supportsRender: true,
      supportsMarkdownExport: true,
      supportsHtmlExport: true,
      supportsSearchIndex: true,
      supportsSync: true,
    ),
    BlockDefinition(
      type: 'math',
      label: 'Math',
      supportsRender: true,
      supportsMarkdownExport: true,
      supportsHtmlExport: true,
      supportsSearchIndex: true,
      supportsSync: true,
    ),
    BlockDefinition(
      type: 'divider',
      label: 'Divider',
      supportsRender: true,
      supportsMarkdownExport: true,
      supportsHtmlExport: true,
      supportsSearchIndex: false,
      supportsSync: true,
    ),
    BlockDefinition(
      type: 'image',
      label: 'Image',
      supportsRender: true,
      supportsMarkdownExport: true,
      supportsHtmlExport: true,
      supportsSearchIndex: false,
      supportsSync: true,
    ),
    BlockDefinition(
      type: 'doodle',
      label: 'Doodle',
      supportsRender: true,
      supportsMarkdownExport: true,
      supportsHtmlExport: true,
      supportsSearchIndex: false,
      supportsSync: true,
    ),
  ];

  static final Map<String, BlockDefinition> _byType = {
    for (final def in definitions) def.type: def,
  };

  /// Looks up a registered block definition by [type], or null if unknown.
  static BlockDefinition? resolve(String type) => _byType[type];

  /// Returns all registered block type identifiers.
  static Set<String> get registeredTypes => _byType.keys.toSet();
}

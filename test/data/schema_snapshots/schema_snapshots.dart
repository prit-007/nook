/// Expected table names and key columns for Nook Drift schema snapshots.
class SchemaSnapshots {
  const SchemaSnapshots._();

  static const int currentVersion = 12;

  static const Set<String> v11Tables = {
    'notebooks',
    'notes',
    'checklist_items',
    'attachments',
    'tags',
    'note_tags',
    'note_links',
    'note_revisions',
    'reminders',
    'templates',
    'trusted_devices',
    'sync_log',
    'notes_fts',
  };

  static const Set<String> v11NoteColumns = {
    'id',
    'title',
    'type',
    'delta_content',
    'plain_text',
    'color_seed',
    'font_style',
    'pinned',
    'locked',
    'archived',
    'deleted',
    'deleted_at',
    'sync_version',
    'device_origin_id',
    'notebook_id',
    'created_at',
    'updated_at',
  };
}

/// View layout modes for the notes scroller on Home.
enum HomeViewMode {
  /// True dynamic masonry grid where cards size to content height.
  masonry,

  /// Comfortable single-column list with title, content preview, tags.
  list,

  /// High-density scannable rows with title, date, and type badge.
  compact,
}

/// Grouping strategies for organizing notes on Home.
enum HomeGroupBy {
  /// Flat sorted scroller.
  none,

  /// Pinned notes at top, followed by Other notes.
  pinned,

  /// Grouped by relative date buckets (Today, Yesterday, This week, Older).
  date,
}

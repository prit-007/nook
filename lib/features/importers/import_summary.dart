/// Shared result type for note importers.
class ImportSummary {
  const ImportSummary({
    this.notesImported = 0,
    this.filesProcessed = 0,
    this.errors = const [],
  });

  final int notesImported;
  final int filesProcessed;
  final List<String> errors;

  bool get isSuccessful => errors.isEmpty;
}

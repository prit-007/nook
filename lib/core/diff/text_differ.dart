import 'dart:typed_data';

/// Types of diff segments.
enum DiffType {
  unchanged,
  inserted,
  deleted,
}

/// A piece of text marked with its diff status.
class DiffSegment {
  const DiffSegment({
    required this.type,
    required this.text,
  });

  final DiffType type;
  final String text;

  @override
  String toString() => 'DiffSegment($type, "$text")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiffSegment &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          text == other.text;

  @override
  int get hashCode => Object.hash(type, text);
}

/// The overall result of comparing two texts.
class DiffResult {
  const DiffResult({
    required this.segments,
    required this.additions,
    required this.deletions,
  });

  final List<DiffSegment> segments;
  final int additions;
  final int deletions;
}

/// Pure Dart diff calculation using Longest Common Subsequence (LCS).
class TextDiffer {
  const TextDiffer._();

  /// Compares two texts line by line.
  static DiffResult diffLines(String oldText, String newText) {
    if (oldText.isEmpty && newText.isEmpty) {
      return const DiffResult(segments: [], additions: 0, deletions: 0);
    }
    if (oldText.isEmpty) {
      final lines = newText.split('\n');
      return DiffResult(
        segments: lines
            .map((l) => DiffSegment(type: DiffType.inserted, text: l))
            .toList(),
        additions: lines.length,
        deletions: 0,
      );
    }
    if (newText.isEmpty) {
      final lines = oldText.split('\n');
      return DiffResult(
        segments: lines
            .map((l) => DiffSegment(type: DiffType.deleted, text: l))
            .toList(),
        additions: 0,
        deletions: lines.length,
      );
    }

    final oldLines = oldText.split('\n');
    final newLines = newText.split('\n');
    final segments = _computeLcsDiff(oldLines, newLines);

    var additions = 0;
    var deletions = 0;
    for (final seg in segments) {
      if (seg.type == DiffType.inserted) additions++;
      if (seg.type == DiffType.deleted) deletions++;
    }

    return DiffResult(
      segments: segments,
      additions: additions,
      deletions: deletions,
    );
  }

  /// Compares two texts word by word, preserving whitespace.
  static DiffResult diffWords(String oldText, String newText) {
    if (oldText.isEmpty && newText.isEmpty) {
      return const DiffResult(segments: [], additions: 0, deletions: 0);
    }

    final wordRegex = RegExp(r'\S+|\s+');
    final oldTokens =
        wordRegex.allMatches(oldText).map((m) => m.group(0)!).toList();
    final newTokens =
        wordRegex.allMatches(newText).map((m) => m.group(0)!).toList();

    final segments = _computeLcsDiff(oldTokens, newTokens);

    var additions = 0;
    var deletions = 0;
    for (final seg in segments) {
      if (seg.text.trim().isEmpty) continue;
      if (seg.type == DiffType.inserted) additions++;
      if (seg.type == DiffType.deleted) deletions++;
    }

    return DiffResult(
      segments: segments,
      additions: additions,
      deletions: deletions,
    );
  }

  /// Computes the diff sequence between two token lists using dynamic programming LCS.
  static List<DiffSegment> _computeLcsDiff(
    List<String> oldTokens,
    List<String> newTokens,
  ) {
    final m = oldTokens.length;
    final n = newTokens.length;

    // dp[i][j] stores the length of LCS of oldTokens[0..i-1] and newTokens[0..j-1]
    final dp = List.generate(m + 1, (_) => Int32List(n + 1));

    for (var i = 0; i < m; i++) {
      for (var j = 0; j < n; j++) {
        if (oldTokens[i] == newTokens[j]) {
          dp[i + 1][j + 1] = dp[i][j] + 1;
        } else {
          final top = dp[i][j + 1];
          final left = dp[i + 1][j];
          dp[i + 1][j + 1] = top > left ? top : left;
        }
      }
    }

    // Backtrack to build the diff list
    final reversed = <DiffSegment>[];
    var i = m;
    var j = n;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && oldTokens[i - 1] == newTokens[j - 1]) {
        reversed
            .add(DiffSegment(type: DiffType.unchanged, text: oldTokens[i - 1]));
        i--;
        j--;
      } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        reversed
            .add(DiffSegment(type: DiffType.inserted, text: newTokens[j - 1]));
        j--;
      } else if (i > 0 && (j == 0 || dp[i][j - 1] < dp[i - 1][j])) {
        reversed
            .add(DiffSegment(type: DiffType.deleted, text: oldTokens[i - 1]));
        i--;
      }
    }

    return reversed.reversed.toList();
  }
}

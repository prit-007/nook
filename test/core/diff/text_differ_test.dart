import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/diff/text_differ.dart';

void main() {
  group('TextDiffer.diffLines', () {
    test('identical text produces unchanged segments', () {
      const text = 'Line 1\nLine 2\nLine 3';
      final result = TextDiffer.diffLines(text, text);

      expect(result.additions, 0);
      expect(result.deletions, 0);
      expect(result.segments.length, 3);
      for (final seg in result.segments) {
        expect(seg.type, DiffType.unchanged);
      }
      expect(result.segments.map((s) => s.text).join('\n'), text);
    });

    test('added lines are marked inserted', () {
      const oldText = 'Line 1\nLine 3';
      const newText = 'Line 1\nLine 2\nLine 3';
      final result = TextDiffer.diffLines(oldText, newText);

      expect(result.additions, 1);
      expect(result.deletions, 0);
      expect(result.segments, hasLength(3));
      expect(result.segments[0].type, DiffType.unchanged);
      expect(result.segments[0].text, 'Line 1');
      expect(result.segments[1].type, DiffType.inserted);
      expect(result.segments[1].text, 'Line 2');
      expect(result.segments[2].type, DiffType.unchanged);
      expect(result.segments[2].text, 'Line 3');
    });

    test('deleted lines are marked deleted', () {
      const oldText = 'Line 1\nLine 2\nLine 3';
      const newText = 'Line 1\nLine 3';
      final result = TextDiffer.diffLines(oldText, newText);

      expect(result.additions, 0);
      expect(result.deletions, 1);
      expect(result.segments, hasLength(3));
      expect(result.segments[0].type, DiffType.unchanged);
      expect(result.segments[0].text, 'Line 1');
      expect(result.segments[1].type, DiffType.deleted);
      expect(result.segments[1].text, 'Line 2');
      expect(result.segments[2].type, DiffType.unchanged);
      expect(result.segments[2].text, 'Line 3');
    });

    test('modified lines show deletion then insertion', () {
      const oldText = 'Hello World';
      const newText = 'Hello Flutter';
      final result = TextDiffer.diffLines(oldText, newText);

      expect(result.additions, 1);
      expect(result.deletions, 1);
      expect(result.segments, hasLength(2));
      expect(result.segments[0].type, DiffType.deleted);
      expect(result.segments[0].text, 'Hello World');
      expect(result.segments[1].type, DiffType.inserted);
      expect(result.segments[1].text, 'Hello Flutter');
    });

    test('empty old text marks all new lines as inserted', () {
      const newText = 'Alpha\nBeta';
      final result = TextDiffer.diffLines('', newText);

      expect(result.additions, 2);
      expect(result.deletions, 0);
      expect(result.segments.every((s) => s.type == DiffType.inserted), isTrue);
    });

    test('empty new text marks all old lines as deleted', () {
      const oldText = 'Alpha\nBeta';
      final result = TextDiffer.diffLines(oldText, '');

      expect(result.additions, 0);
      expect(result.deletions, 2);
      expect(result.segments.every((s) => s.type == DiffType.deleted), isTrue);
    });
  });

  group('TextDiffer.diffWords', () {
    test('diffs at word granularity within a sentence', () {
      const oldText = 'The quick brown fox';
      const newText = 'The fast brown fox';
      final result = TextDiffer.diffWords(oldText, newText);

      expect(result.additions, 1);
      expect(result.deletions, 1);

      final words = result.segments.map((s) => s.text).toList();
      expect(words, contains('The'));
      expect(words, contains('quick'));
      expect(words, contains('fast'));
      expect(words, contains('brown'));
      expect(words, contains('fox'));

      final quickSeg = result.segments.firstWhere((s) => s.text == 'quick');
      final fastSeg = result.segments.firstWhere((s) => s.text == 'fast');
      expect(quickSeg.type, DiffType.deleted);
      expect(fastSeg.type, DiffType.inserted);
    });
  });
}

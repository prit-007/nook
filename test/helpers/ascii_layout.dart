import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String asciiLayout(
  WidgetTester tester,
  Map<String, Finder> regions, {
  int cols = 100,
  int rows = 30,
}) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  if (size.width <= 0 || size.height <= 0) return '';
  final grid = List.generate(rows, (_) => List.filled(cols, ' '));
  int cx(double x) => (x / size.width * (cols - 1)).round().clamp(0, cols - 1);
  int cy(double y) => (y / size.height * (rows - 1)).round().clamp(0, rows - 1);

  for (final e in regions.entries) {
    if (e.value.evaluate().isEmpty) continue;
    final r = tester.getRect(e.value.first);
    final x0 = cx(r.left), x1 = cx(r.right), y0 = cy(r.top), y1 = cy(r.bottom);
    for (var x = x0; x <= x1; x++) {
      grid[y0][x] = '-';
      grid[y1][x] = '-';
    }
    for (var y = y0; y <= y1; y++) {
      grid[y][x0] = '|';
      grid[y][x1] = '|';
    }
    for (final c in [
      [y0, x0],
      [y0, x1],
      [y1, x0],
      [y1, x1],
    ]) {
      grid[c[0]][c[1]] = '+';
    }
    final ly = (y0 + 1 <= y1) ? y0 + 1 : y0;
    for (var i = 0; i < e.key.length && x0 + 1 + i < x1; i++) {
      grid[ly][x0 + 1 + i] = e.key[i];
    }
  }
  return grid.map((r) => r.join().trimRight()).join('\n');
}

void expectLayoutSnap(String actual, String name) {
  final f = File('test/layout_snaps/$name.txt');
  if (Platform.environment['UPDATE_SNAPS'] == '1' || !f.existsSync()) {
    f.createSync(recursive: true);
    f.writeAsStringSync(actual);
    return;
  }
  expect(actual, f.readAsStringSync(), reason: 'Layout changed: $name');
}

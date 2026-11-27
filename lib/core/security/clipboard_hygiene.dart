import 'dart:async';

import 'package:flutter/services.dart';

/// Copies sensitive data to the system clipboard and automatically clears it
/// after [clearAfter] (default 60 seconds).
class ClipboardHygiene {
  ClipboardHygiene({
    Future<void> Function(String text)? writeClipboard,
  }) : _writeClipboard = writeClipboard ??
            ((text) => Clipboard.setData(ClipboardData(text: text)));

  final Future<void> Function(String text) _writeClipboard;
  Timer? _timer;

  bool get hasPendingClear => _timer?.isActive ?? false;

  Future<void> copyWithAutoClear(
    String text, {
    Duration clearAfter = const Duration(seconds: 60),
  }) async {
    await _writeClipboard(text);
    _timer?.cancel();
    _timer = Timer(clearAfter, () {
      unawaited(_writeClipboard(''));
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

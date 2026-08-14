import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Re-exported so call sites that use [nookLog] can reference [LogLevel]
/// without importing the talker package directly.
export 'package:talker_flutter/talker_flutter.dart' show LogLevel;

/// Domain keys for app logs. Each key maps to its own color in the in-app
/// logs screen and to its own ANSI pen in the console, so the "sync",
/// "database", "editor" and "security" buckets can be filtered independently.
abstract final class NookLogKey {
  static const sync = 'sync';
  static const database = 'database';
  static const editor = 'editor';
  static const security = 'security';
}

/// The single shared Talker instance.
///
/// Created once at import time (the top-level equivalent of the plan's
/// `main()` global) so error handlers in `main()` and every logging call site
/// across the app reference the same logger and the same history.
final Talker talker = TalkerFlutter.init(
  settings: TalkerSettings(
    titles: {
      NookLogKey.sync: 'sync',
      NookLogKey.database: 'database',
      NookLogKey.editor: 'editor',
      NookLogKey.security: 'security',
    },
    colors: {
      NookLogKey.sync: AnsiPen()..xterm(141), // blue-purple
      NookLogKey.database: AnsiPen()..xterm(44), // teal
      NookLogKey.editor: AnsiPen()..xterm(214), // amber
      NookLogKey.security: AnsiPen()..xterm(205), // rose
    },
  ),
);

/// Logs [message] tagged with a [NookLogKey] so it is filterable and colored
/// by domain in the in-app logs screen.
void nookLog(String key, String message, [LogLevel level = LogLevel.debug]) {
  talker.logCustom(TalkerLog(message, key: key, logLevel: level));
}

/// Riverpod access to the shared [talker] instance.
final talkerProvider = Provider<Talker>((ref) => talker);

/// Emits the current log history size immediately, then again on every new
/// log so widgets (e.g. the Settings "App Logs" tile) show a live count.
final talkerLogCountProvider = StreamProvider<int>((ref) async* {
  final talker = ref.watch(talkerProvider);
  yield talker.history.length;
  await for (final _ in talker.stream) {
    yield talker.history.length;
  }
});

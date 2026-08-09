import 'dart:io';

/// Idempotently patches `appflowy_editor` 6.2.0's `DeltaTextInputService` to
/// implement `TextInputClient.onFocusReceived`.
///
/// Flutter 3.44+ added `TextInputClient.onFocusReceived`, and the pristine
/// package does not implement it, so any test/app importing the editor fails
/// to compile:
///
///   Error: The non-abstract class 'DeltaTextInputService' is missing
///   implementations for these members: - TextInputClient.onFocusReceived
///
/// The fix is the same override the sibling `NonDeltaTextInputService` already
/// ships. This script must run after `flutter pub get` in CI.
///
/// Remove this script once `appflowy_editor` publishes the override
/// (>= 6.2.1). Track: https://github.com/AppFlowy-IO/appflowy-editor/issues/1036
Future<void> main() async {
  final pubCache = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final file = File(
    '$pubCache/hosted/pub.dev/appflowy_editor-6.2.0/'
    'lib/src/editor/editor_component/service/ime/delta_input_service.dart',
  );
  if (!file.existsSync()) {
    stderr.writeln('appflowy_editor-6.2.0 not found at $file');
    exitCode = 1;
    return;
  }

  var source = file.readAsStringSync();
  if (source.contains('bool onFocusReceived()')) {
    stdout.writeln('appflowy_editor: already patched, skipping.');
    return;
  }

  const anchor = '  void insertContent(KeyboardInsertedContent content) {}\n\n';
  final index = source.indexOf(anchor);
  if (index == -1) {
    stderr.writeln(
        'appflowy_editor: insertion anchor not found; refusing to patch.');
    exitCode = 1;
    return;
  }

  const override = '  @override\n  bool onFocusReceived() => attached;\n\n';
  source = source.replaceFirst(anchor, anchor + override);
  file.writeAsStringSync(source);
  stdout.writeln(
      'appflowy_editor: patched DeltaTextInputService.onFocusReceived.');
}

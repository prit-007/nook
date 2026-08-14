import 'dart:io';

/// Idempotently patches `appflowy_editor` 6.2.0 in the pub cache.
///
/// Patches:
///
/// 1. `DeltaTextInputService` — implements `TextInputClient.onFocusReceived`.
///    Flutter 3.44+ added `TextInputClient.onFocusReceived`, and the pristine
///    package does not implement it, so any test/app importing the editor fails
///    to compile:
///
///      Error: The non-abstract class 'DeltaTextInputService' is missing
///      implementations for these members: - TextInputClient.onFocusReceived
///
///    The fix is the same override the sibling `NonDeltaTextInputService`
///    already ships.
///
/// 2. `slash_command.dart` — makes the `/` slash command work on mobile.
///    Currently `_showSlashMenu` returns false immediately on mobile, so
///    typing `/` silently does nothing. Simply removing the guard is not
///    enough: the SelectionMenu overlay closes the soft keyboard and relies on
///    hardware-keyboard navigation, which is unusable on touch devices. The
///    patch inserts the slash character (a visual breadcrumb) and consumes the
///    event without showing the overlay. The actual block insertion happens
///    through the mobile toolbar instead.
///
/// This script must run after `flutter pub get` in CI. Remove it once
/// `appflowy_editor` publishes these fixes.
/// Track: https://github.com/AppFlowy-IO/appflowy-editor/issues/1036
Future<void> main() async {
  final pubCache = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final base = '$pubCache/hosted/pub.dev/appflowy_editor-6.2.0/lib/src';

  var ok = true;
  ok = _patchDeltaInputService(
        '$base/editor/editor_component/service/ime/delta_input_service.dart',
      ) &&
      ok;
  ok = _patchSlashCommand(
        '$base/editor/editor_component/service/shortcuts/character/'
        'slash_command.dart',
      ) &&
      ok;
  if (!ok) exitCode = 1;
}

bool _patchDeltaInputService(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('appflowy_editor: not found at $path');
    return false;
  }

  var source = file.readAsStringSync();
  if (source.contains('bool onFocusReceived()')) {
    stdout.writeln('appflowy_editor: DeltaTextInputService already patched.');
    return true;
  }

  const anchor = '  void insertContent(KeyboardInsertedContent content) {}\n\n';
  final index = source.indexOf(anchor);
  if (index == -1) {
    stderr.writeln('appflowy_editor: DeltaTextInputService anchor not found; '
        'refusing to patch.');
    return false;
  }

  const override = '  @override\n  bool onFocusReceived() => attached;\n\n';
  source = source.replaceFirst(anchor, anchor + override);
  file.writeAsStringSync(source);
  stdout.writeln(
      'appflowy_editor: patched DeltaTextInputService.onFocusReceived.');
  return true;
}

bool _patchSlashCommand(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('appflowy_editor: not found at $path');
    return false;
  }

  var source = file.readAsStringSync();
  if (source.contains('// nook: mobile slash insert')) {
    stdout.writeln('appflowy_editor: slash_command.dart already patched.');
    return true;
  }

  const anchor = '''  if (PlatformExtension.isMobile) {
    return false;
  }

  final selection = editorState.selection;
  if (selection == null) {
    return false;
  }
''';

  const patched =
      '''  // nook: mobile slash insert — on touch devices, insert the slash character
  // (a visual breadcrumb) and consume the event without showing the
  // SelectionMenu overlay, which closes the soft keyboard and relies on
  // hardware-keyboard navigation. Block insertion happens via the mobile
  // toolbar instead.
  final selection = editorState.selection;
  if (PlatformExtension.isMobile) {
    if (selection != null && shouldInsertSlash) {
      await editorState.insertTextAtPosition('/', position: selection.start);
    }
    return true;
  }
  if (selection == null) {
    return false;
  }
''';

  final index = source.indexOf(anchor);
  if (index == -1) {
    stderr.writeln(
        'appflowy_editor: slash_command.dart anchor not found; refusing to '
        'patch.');
    return false;
  }

  source = source.replaceFirst(anchor, patched);
  file.writeAsStringSync(source);
  stdout.writeln('appflowy_editor: patched slash_command.dart mobile guard.');
  return true;
}

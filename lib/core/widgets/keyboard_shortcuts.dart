import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Global keyboard shortcuts for desktop / web.
///
/// Bindings (all disabled while a text input has focus so typing is never
/// hijacked):
///
/// - `/`              → open search (`/home/search`)
/// - Ctrl/Cmd + K     → open search
/// - Ctrl/Cmd + N     → new note (`/note/new`)
/// - Ctrl+Shift+N     → quick note overlay
class NookKeyboardShortcuts extends StatefulWidget {
  const NookKeyboardShortcuts({
    super.key,
    required this.child,
    this.onOpenSearch,
    this.onNewNote,
    this.onQuickNote,
  });

  final Widget child;

  /// Injectable actions for tests. When null, navigation via go_router is used.
  final VoidCallback? onOpenSearch;
  final VoidCallback? onNewNote;
  final VoidCallback? onQuickNote;

  @override
  State<NookKeyboardShortcuts> createState() => _NookKeyboardShortcutsState();
}

class _NookKeyboardShortcutsState extends State<NookKeyboardShortcuts> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'nook-global-shortcuts');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Only fire global shortcuts when no editable text region owns the primary
  /// focus. Two cases are handled:
  ///
  /// 1. Flutter text inputs (`TextField`, `SearchBar`, ...) — the primary
  ///    focus lands on the internal `Focus` widget that `EditableText` builds,
  ///    so we walk the focused widget's ancestor chain for an `EditableText`.
  /// 2. The AppFlowy editor — it wraps itself in its own `FocusScope`
  ///    (`editor_component.dart`), so any focus inside it lives in a nested
  ///    scope, unlike plain buttons/cards which share the app root scope.
  bool get _canUseShortcuts {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return true;
    final focusedContext = focus.context;
    if (focusedContext != null) {
      if (focusedContext.widget is EditableText) return false;
      if (focusedContext.findAncestorWidgetOfExactType<EditableText>() !=
          null) {
        return false;
      }
    }
    return focus.enclosingScope == FocusScope.of(context);
  }

  void _openSearch() {
    if (!_canUseShortcuts) return;
    final onOpenSearch = widget.onOpenSearch;
    if (onOpenSearch != null) {
      onOpenSearch();
      return;
    }
    if (!context.mounted) return;
    HapticFeedback.lightImpact();
    context.push('/home/search');
  }

  void _newNote() {
    if (!_canUseShortcuts) return;
    final onNewNote = widget.onNewNote;
    if (onNewNote != null) {
      onNewNote();
      return;
    }
    if (!context.mounted) return;
    HapticFeedback.lightImpact();
    context.push('/note/new');
  }

  void _quickNote() {
    if (!_canUseShortcuts) return;
    final onQuickNote = widget.onQuickNote;
    if (onQuickNote != null) {
      onQuickNote();
      return;
    }
    // Quick note is handled by the global hotkey system — this binding
    // provides the in-app fallback for when the app is focused.
    HapticFeedback.lightImpact();
    // The overlay is pushed via the navigator key from main.dart.
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.slash): _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openSearch,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _newNote,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _newNote,
        const SingleActivator(LogicalKeyboardKey.keyN,
            control: true, shift: true): _quickNote,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true):
            _quickNote,
      },
      // The root focusable guarantees a primary focus exists so key events are
      // routed through the Shortcuts system from the very first frame.
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: widget.child,
      ),
    );
  }
}

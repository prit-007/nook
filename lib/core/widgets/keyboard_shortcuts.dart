import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Global keyboard shortcuts for desktop / web.
///
/// Bindings (all disabled while a text input has focus so typing is never
/// hijacked — e.g. the AppFlowy editor's `/` slash menu keeps working):
///
/// - `/`            → open search (`/home/search`)
/// - Ctrl/Cmd + K   → open search
/// - Ctrl/Cmd + N   → new note (`/note/new`)
///
/// [CallbackShortcuts] resolves bindings from the primary focus upward, so a
/// descendant that consumes the key (a text field's character input, the
/// editor's `/` slash command) wins before this handler runs. For keys that
/// bubble up (Ctrl/Cmd + K/N while typing), the guard below refuses to fire.
class NookKeyboardShortcuts extends StatefulWidget {
  const NookKeyboardShortcuts({
    super.key,
    required this.child,
    this.onOpenSearch,
    this.onNewNote,
  });

  final Widget child;

  /// Injectable actions for tests. When null, navigation via go_router is used.
  final VoidCallback? onOpenSearch;
  final VoidCallback? onNewNote;

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

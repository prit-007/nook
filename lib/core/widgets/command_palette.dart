import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../commands/command_registry.dart';

/// Opens the command palette dialog.
///
/// [onExecute] runs after the dialog closes so route changes use the app
/// navigator. Create-note commands call [onCreateNote] with their [NoteType].
Future<void> showCommandPalette(
  BuildContext context, {
  required List<NookCommand> commands,
  required void Function(NookCommand command, BuildContext appContext)
      onExecute,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => CommandPaletteDialog(
      commands: commands,
      onExecute: (command) => onExecute(command, context),
    ),
  );
}

class CommandPaletteDialog extends StatefulWidget {
  const CommandPaletteDialog({
    super.key,
    required this.commands,
    required this.onExecute,
  });

  final List<NookCommand> commands;
  final void Function(NookCommand command) onExecute;

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<NookCommand> get _filtered =>
      filterCommands(widget.commands, _controller.text);

  void _run(NookCommand command) {
    Navigator.of(context).pop();
    widget.onExecute(command);
  }

  void _runSelected() {
    final list = _filtered;
    if (list.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final idx = _index.clamp(0, list.length - 1);
    _run(list[idx]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = _filtered;
    if (list.isNotEmpty && _index >= list.length) {
      _index = list.length - 1;
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Type a command…',
                  prefixIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onChanged: (_) => setState(() => _index = 0),
                onSubmitted: (_) => _runSelected(),
              ),
            ),
            Flexible(
              child: list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No matching commands',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final cmd = list[index];
                        final selected = index == _index;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor:
                              scheme.primaryContainer.withValues(alpha: 0.35),
                          leading: HugeIcon(
                            icon: cmd.icon,
                            size: 20,
                            color: selected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          title: Text(cmd.title),
                          onTap: () => _run(cmd),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

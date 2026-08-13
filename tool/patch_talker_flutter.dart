import 'dart:io';

/// Idempotently patches `talker_flutter 5.1.16` in the pub cache so the
/// package's `ListTile`s never trigger Flutter's "ListTile background color or
/// ink splashes may be invisible" framework warning.
///
/// The framework walks from each `ListTile` up to its nearest `Material` and
/// complains if a `DecoratedBox`/`ColoredBox` with a background color sits in
/// between (its ink splash would be painted beneath that background). The
/// package renders both the actions bottom sheet and the settings cards with a
/// tinted container directly around their `ListTile`s:
///
/// - `talker_actions_bottom_sheet.dart` — 6 `_ActionTile` ListTiles inside a
///   `Container(color: talkerScreenTheme.backgroundColor)`.
/// - `talker_settings/widgets/talker_setting_card.dart` — a ListTile inside
///   `TalkerBaseCard` (tinted background).
///
/// The fix wraps those subtrees in `Material(type: MaterialType.transparency)`
/// so the ListTiles paint their ink on a Material below the tinted box.
///
/// Run after `flutter pub get` in CI. Remove once upstream wraps the tiles in
/// a Material.
Future<void> main() async {
  final pubCache = Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final base = '$pubCache/hosted/pub.dev/talker_flutter-5.1.16/lib/src/ui';

  var ok = true;
  ok = _patchActionsSheet(
          '$base/talker_actions/talker_actions_bottom_sheet.dart') &&
      ok;
  ok = _patchSettingsCard(
        '$base/talker_settings/widgets/talker_setting_card.dart',
      ) &&
      ok;
  if (!ok) exitCode = 1;
}

bool _patchActionsSheet(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('talker_flutter: not found at $path');
    return false;
  }

  var source = file.readAsStringSync();
  if (source.contains('// nook: Material wrapper for the action list')) {
    stdout.writeln('talker_flutter: actions bottom sheet already patched.');
    return true;
  }

  const openAnchor = '''      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 16),
        decoration: BoxDecoration(
          color: talkerScreenTheme.backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
''';

  const openReplacement = '''      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 16),
        decoration: BoxDecoration(
          color: talkerScreenTheme.backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        // nook: Material wrapper for the action list — keeps the ListTile ink
        // splash on top of the tinted DecoratedBox (framework warning fix).
        child: Material(
          type: MaterialType.transparency,
          child: Column(
''';

  const closeAnchor = '''          ],
        ),
      ),
    );
  }
}
''';

  const closeReplacement = '''          ],
          ),
        ),
      ),
    );
  }
}
''';

  if (source.contains(openAnchor)) {
    source = source.replaceFirst(openAnchor, openReplacement);
  } else {
    stderr.writeln('talker_flutter: actions open anchor not found; skipping.');
    return false;
  }

  if (source.contains(closeAnchor)) {
    source = source.replaceFirst(closeAnchor, closeReplacement);
  } else {
    stderr.writeln('talker_flutter: actions close anchor not found; skipping.');
    return false;
  }

  file.writeAsStringSync(source);
  stdout.writeln('talker_flutter: patched talker_actions_bottom_sheet.dart.');
  return true;
}

bool _patchSettingsCard(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('talker_flutter: not found at $path');
    return false;
  }

  var source = file.readAsStringSync();
  if (source.contains('// nook: Material wrapper for the setting card')) {
    stdout.writeln('talker_flutter: settings card already patched.');
    return true;
  }

  const openAnchor = '''          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
''';

  const openReplacement = '''          child: Material(
            // nook: Material wrapper for the setting card — keeps the ListTile
            // ink splash on top of the tinted card (framework warning fix).
            type: MaterialType.transparency,
            child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
''';

  const closeAnchor = '''            ),
          ),
        ),
      ),
    );
  }
}
''';

  const closeReplacement = '''            ),
          ),
          ),
        ),
      ),
    );
  }
}
''';

  if (source.contains(openAnchor)) {
    source = source.replaceFirst(openAnchor, openReplacement);
  } else {
    stderr.writeln(
        'talker_flutter: settings card open anchor not found; skipping.');
    return false;
  }

  if (source.contains(closeAnchor)) {
    source = source.replaceFirst(closeAnchor, closeReplacement);
  } else {
    stderr.writeln(
        'talker_flutter: settings card close anchor not found; skipping.');
    return false;
  }

  file.writeAsStringSync(source);
  stdout.writeln('talker_flutter: patched talker_setting_card.dart.');
  return true;
}

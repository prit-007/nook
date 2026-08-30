import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_info.dart';
import '../update_provider.dart';

/// Presents the outcome of a manual "Check for Updates" tap as a dialog.
Future<void> showUpdateDialog(
  BuildContext context,
  WidgetRef ref,
  UpdateStatus status,
) {
  final current = ref.read(appInfoProvider).maybeWhen(
        data: (info) => info.version,
        orElse: () => '',
      );
  final info = status.available;

  if (info != null) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('nook v${info.latestVersion} is ready to install.'),
            if (info.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Flexible(
                child: Text(
                  info.notes.trim(),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(updateStatusProvider.notifier).dismiss();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              if (info.releaseUrl.isEmpty) return;
              try {
                final uri = Uri.parse(info.releaseUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } catch (_) {
                // Best-effort — user can download manually.
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  if (status.hasError) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Couldn't check for updates"),
        content: const Text(
          'nook could not reach the release feed. Check your connection and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text("You're up to date"),
      content: Text('nook v$current is the latest release.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// A white, rounded QR code card with the encoded [data] beneath it, plus a
/// copy-to-clipboard action. Reused by the receive screen (mobile receives
/// from desktop) and the send screen (desktop shows QR for the mobile to scan).
class QrDisplayCard extends StatelessWidget {
  const QrDisplayCard({
    super.key,
    required this.data,
    this.title = 'Scan to connect',
    this.caption,
    this.onCopy,
  });

  final String data;
  final String title;
  final String? caption;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 260,
        height: 360,
        child: Column(
          children: [
            if (caption != null) ...[
              Text(
                caption!,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black12,
                  width: 1,
                ),
              ),
              child: QrImageView(
                data: data,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                // High-contrast black-on-white, square modules: crisp edges
                // that scan reliably and stay sharp on small phone screens.
                eyeStyle: const QrEyeStyle(
                  color: Colors.black,
                  eyeShape: QrEyeShape.square,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  color: Colors.black,
                  dataModuleShape: QrDataModuleShape.square,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              data,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (onCopy != null)
          FilledButton.tonal(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: data));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Address copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              onCopy?.call();
            },
            child: const Text('Copy Address'),
          ),
      ],
    );
  }
}

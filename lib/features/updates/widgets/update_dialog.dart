import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Premium update dialog with animated download state.
///
/// On Android, downloads the APK and triggers installation.
/// On desktop, redirects to the GitHub releases page.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.currentVersion,
    required this.newVersion,
    this.changelog = const [],
    this.apkUrl,
    this.releaseUrl,
  });

  final String currentVersion;
  final String newVersion;
  final List<String> changelog;
  final String? apkUrl;
  final String? releaseUrl;

  /// Shows the update dialog globally.
  static Future<void> show(
    BuildContext context, {
    required String current,
    required String newVer,
    List<String> changelog = const [],
    String? apkUrl,
    String? releaseUrl,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(
        currentVersion: current,
        newVersion: newVer,
        changelog: changelog,
        apkUrl: apkUrl,
        releaseUrl: releaseUrl,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  double _downloadedMb = 0.0;
  double _totalMb = 0.0;
  String? _error;
  bool _installing = false;
  http.Client? _downloadClient;

  @override
  void dispose() {
    _downloadClient?.close();
    super.dispose();
  }

  bool get _isDesktop =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  Future<void> _startDownload() async {
    if (_isDesktop) {
      // Desktop: redirect to GitHub releases page.
      await _openReleasePage();
      return;
    }

    if (widget.apkUrl == null || widget.apkUrl!.isEmpty) {
      // No APK URL available — fall back to release page.
      await _openReleasePage();
      return;
    }

    setState(() {
      _isDownloading = true;
      _error = null;
      _progress = 0.0;
      _downloadedMb = 0.0;
    });

    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'nook_${widget.newVersion}.apk';
      final file = File('${dir.path}/$fileName');

      _downloadClient = http.Client();
      final request = http.Request('GET', Uri.parse(widget.apkUrl!));
      final response = await _downloadClient!.send(request).timeout(
            const Duration(minutes: 5),
          );

      if (response.statusCode != 200) {
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }

      _totalMb = (response.contentLength ?? 0) / (1024 * 1024);
      if (_totalMb <= 0) _totalMb = 77.0; // fallback estimate

      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (mounted) {
          setState(() {
            _downloadedMb = received / (1024 * 1024);
            _progress =
                _totalMb > 0 ? (_downloadedMb / _totalMb).clamp(0.0, 1.0) : 0.0;
          });
        }
      }
      await sink.close();
      _downloadClient?.close();
      _downloadClient = null;

      if (mounted) {
        setState(() {
          _progress = 1.0;
          _installing = true;
        });
      }

      // Trigger APK installation.
      await _installApk(file.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Download failed: $e';
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _installApk(String apkPath) async {
    try {
      final result = await OpenFilex.open(apkPath);
      if (result.type == ResultType.done) {
        if (mounted) Navigator.of(context).pop();
      } else {
        // Fallback: try url_launcher with file:// URI.
        final uri = Uri.file(apkPath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Installation failed: $e';
          _installing = false;
          _isDownloading = false;
        });
      }
    }
  }

  Future<void> _openReleasePage() async {
    final url =
        widget.releaseUrl ?? 'https://github.com/prit-007/nook/releases';
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Best-effort.
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedDownload04,
                    color: scheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Update Available',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'A new version is ready',
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 2. Version Comparison Pill
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _VersionBadge(
                    label: 'Current',
                    version: widget.currentVersion,
                    color: scheme.surfaceContainerHighest,
                    textColor: scheme.onSurfaceVariant,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      color: scheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  _VersionBadge(
                    label: 'New',
                    version: widget.newVersion,
                    color: scheme.primary,
                    textColor: scheme.onPrimary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Dynamic Content Area
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isDownloading
                    ? _buildDownloadingState(scheme)
                    : _buildChangelogState(scheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangelogState(ColorScheme scheme) {
    return Column(
      key: const ValueKey('changelog'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (widget.changelog.isNotEmpty) ...[
          Text(
            "What's New",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 140),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.changelog
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ',
                                  style: TextStyle(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        FilledButton.icon(
          onPressed: _startDownload,
          icon: HugeIcon(
              icon: _isDesktop
                  ? HugeIcons.strokeRoundedLink01
                  : HugeIcons.strokeRoundedDownload04,
              size: 20),
          label: Text(
            _isDesktop ? 'Open Release Page' : 'Download & Install',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant),
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('View Release Notes',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloadingState(ColorScheme scheme) {
    return Container(
      key: const ValueKey('downloading'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: _installing
                    ? HugeIcon(
                        icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                        size: 16,
                        color: scheme.primary,
                      )
                    : CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: scheme.primary,
                      ),
              ),
              const SizedBox(width: 12),
              Text(
                _installing ? 'Installing...' : 'Downloading...',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_downloadedMb.toStringAsFixed(1)} / ${_totalMb.toStringAsFixed(1)} MB',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${(_progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (!_installing)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  _downloadClient?.close();
                  _downloadClient = null;
                  setState(() {
                    _isDownloading = false;
                    _progress = 0.0;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({
    required this.label,
    required this.version,
    required this.color,
    required this.textColor,
  });

  final String label;
  final String version;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            version,
            style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
          ),
        ),
      ],
    );
  }
}

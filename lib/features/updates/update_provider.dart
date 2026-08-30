import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_info.dart';
import '../../core/providers/talker_provider.dart';
import 'update_checker.dart';
import 'update_models.dart';

const _lastCheckedKey = 'update_last_checked_at';
const _dismissedKey = 'update_dismissed_version';

/// How often an automatic (non-forced) check may hit the release feed.
const autoCheckThrottle = Duration(hours: 6);

/// Compile-time flag set by `flutter test`; disables the automatic check so
/// widget tests never touch the network.
const _inTest = bool.fromEnvironment('flutter.test');

/// Injectable [UpdateChecker] — override in tests.
final updateCheckerProvider = Provider<UpdateChecker>((ref) => UpdateChecker());

/// Immutable snapshot of the update check's outcome, consumed by the Home
/// banner and the Settings "Check for Updates" tile.
class UpdateStatus {
  const UpdateStatus({
    this.available,
    this.latestChecked,
    this.checking = false,
    this.error,
    this.dismissed = false,
  });

  /// Non-null when a newer release exists.
  final UpdateInfo? available;

  /// The newest release tag seen by the last successful check, even when it is
  /// not newer than the running version (drives the "Up to date" label).
  final AppVersion? latestChecked;

  final bool checking;
  final String? error;

  /// True once the user dismissed [available] for this exact version; a newer
  /// release resets it.
  final bool dismissed;

  bool get hasUpdate => available != null && !dismissed;
  bool get hasError => error != null;
}

/// Backs [updateStatusProvider]: runs the release-feed check, remembers when it
/// last ran, and persists the user's dismissal per version.
class UpdateNotifier extends Notifier<UpdateStatus> {
  @override
  UpdateStatus build() {
    unawaited(checkIfStale());
    return const UpdateStatus();
  }

  /// Runs a throttled check (at most once per [autoCheckThrottle]) unless
  /// running under `flutter test`. Safe to call on every app resume.
  Future<void> checkIfStale() async {
    if (_inTest) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_lastCheckedKey);
      if (last != null &&
          DateTime.now().millisecondsSinceEpoch - last <
              autoCheckThrottle.inMilliseconds) {
        return;
      }
    } catch (_) {
      // Storage unavailable — bail out rather than erroring on every build.
      return;
    }
    await check();
  }

  /// Contacts the release feed (ignoring the throttle when [force] is true).
  /// Returns the resulting status so the caller can present a dialog.
  Future<UpdateStatus> check({bool force = false}) async {
    state = UpdateStatus(
      available: state.available,
      latestChecked: state.latestChecked,
      dismissed: state.dismissed,
      checking: true,
    );
    nookLog(NookLogKey.updates, 'Checking for updates', LogLevel.info);
    try {
      final appInfo = await ref.read(appInfoProvider.future);
      final current = AppVersion.parse(appInfo.version);
      final release =
          await ref.read(updateCheckerProvider).fetchLatestRelease();

      if (release == null || release.tagName.isEmpty) {
        nookLog(
          NookLogKey.updates,
          'No releases published — up to date',
          LogLevel.info,
        );
        state = const UpdateStatus();
        return state;
      }

      final latest = AppVersion.parse(release.tagName);
      if (latest.isNewerThan(current)) {
        final dismissedVersion = await _dismissedVersion();
        final dismissed = dismissedVersion == latest.raw;
        nookLog(
          NookLogKey.updates,
          'Update available: ${latest.raw} (running ${current.raw})',
          LogLevel.info,
        );
        state = UpdateStatus(
          available: UpdateInfo(
            currentVersion: current,
            latestVersion: latest,
            releaseUrl: release.htmlUrl,
            releaseName: release.name,
            notes: release.body,
            publishedAt: release.publishedAt,
            apkUrl: release.apkUrl,
            changelog: _parseChangelog(release.body),
          ),
          latestChecked: latest,
          dismissed: dismissed,
        );
      } else {
        nookLog(
          NookLogKey.updates,
          'Up to date at ${current.raw}',
          LogLevel.info,
        );
        state = UpdateStatus(latestChecked: latest);
      }
      await _saveCheckedAt();
      return state;
    } catch (e) {
      nookLog(
        NookLogKey.updates,
        'Update check failed: $e',
        LogLevel.error,
      );
      state = UpdateStatus(
        available: state.available,
        latestChecked: state.latestChecked,
        dismissed: state.dismissed,
        error: '$e',
      );
      return state;
    }
  }

  /// Remembers the offered version so the banner stays hidden until a newer
  /// release replaces it.
  Future<void> dismiss() async {
    final info = state.available;
    if (info == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedKey, info.latestVersion.raw);
    } catch (_) {
      // Storage unavailable — dismissal still applies for this session.
    }
    nookLog(
      NookLogKey.updates,
      'Update ${info.latestVersion.raw} dismissed',
      LogLevel.info,
    );
    state = UpdateStatus(
      available: info,
      latestChecked: info.latestVersion,
      dismissed: true,
    );
  }

  Future<String?> _dismissedVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_dismissedKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCheckedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastCheckedKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // Non-fatal: the app just re-checks sooner than the throttle.
    }
  }

  /// Parses release body markdown into changelog lines.
  static List<String> _parseChangelog(String body) {
    if (body.trim().isEmpty) return [];
    final lines = body.split('\n');
    final changelog = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        changelog.add(trimmed.substring(2));
      } else if (trimmed.startsWith('#')) {
        continue; // skip headers
      }
    }
    return changelog.isEmpty ? [body.trim()] : changelog;
  }
}

final updateStatusProvider =
    NotifierProvider<UpdateNotifier, UpdateStatus>(UpdateNotifier.new);

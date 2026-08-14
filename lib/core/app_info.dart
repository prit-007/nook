import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Single source of truth for the in-app version string.
///
/// Loaded at runtime from the platform binary metadata via
/// [PackageInfo.fromPlatform], which is generated from the `version:` field
/// in `pubspec.yaml` at build time. There is therefore exactly one place to
/// bump the version — `pubspec.yaml` — and every screen that shows it stays
/// in sync automatically.
class AppInfo {
  AppInfo._(this.version, this.buildNumber);

  factory AppInfo.fromPackageInfo(PackageInfo info) =>
      AppInfo._(info.version, info.buildNumber);

  final String version;
  final String buildNumber;

  /// e.g. `0.7.9+2`
  String get versionLabel => '$version+$buildNumber';
}

/// Riverpod access to the app's [AppInfo], resolved asynchronously from the
/// platform at first read and cached by the provider afterwards.
final appInfoProvider = FutureProvider<AppInfo>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppInfo.fromPackageInfo(info);
});

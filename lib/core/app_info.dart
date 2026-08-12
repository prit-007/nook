/// Single source of truth for the in-app version string.
///
/// Mirrors `version:` in pubspec.yaml. Replace with `package_info_plus` at
/// release time if version-from-binary is ever needed; a constant keeps the
/// pre-alpha build honest without a plugin round-trip.
class AppInfo {
  AppInfo._();

  static const String version = '0.6.2';
  static const String buildNumber = '1';
  static const String versionLabel = '$version+$buildNumber';
}

/// Version + update primitives for the in-app update check.
library;

/// A semantic version parsed from either the app's `pubspec.yaml` version or a
/// GitHub release tag (e.g. `0.8.0`, `v0.8.0`, `1.2.3+4`).
///
/// Build metadata (`+N`) and pre-release suffixes (`-beta`) are ignored for
/// ordering; the numeric `major.minor.patch` tuple drives comparisons.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, [this.raw = '']);

  factory AppVersion.parse(String input) {
    final raw = input.trim();
    final numeric =
        raw.split(RegExp(r'[-+]')).first.replaceFirst(RegExp(r'^[^0-9]*'), '');
    final parts = numeric.split('.');
    int part(int index) {
      if (index >= parts.length) return 0;
      return int.tryParse(parts[index]) ?? 0;
    }

    return AppVersion(part(0), part(1), part(2), raw);
  }

  final int major;
  final int minor;
  final int patch;

  /// The untrimmed source string (e.g. `v0.9.0`).
  final String raw;

  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => raw.isEmpty ? '$major.$minor.$patch' : raw;
}

/// A concrete newer release offered to the user.
class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    required this.releaseName,
    required this.notes,
    required this.publishedAt,
  });

  final AppVersion currentVersion;
  final AppVersion latestVersion;
  final String releaseUrl;
  final String releaseName;
  final String notes;
  final DateTime? publishedAt;
}

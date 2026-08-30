import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown when the update source cannot be reached or returns malformed data.
class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => 'UpdateCheckException: $message';
}

/// A single GitHub release as returned by the releases API.
class GithubRelease {
  const GithubRelease({
    required this.tagName,
    required this.name,
    required this.htmlUrl,
    required this.body,
    required this.publishedAt,
    required this.draft,
    required this.prerelease,
  });

  final String tagName;
  final String name;
  final String htmlUrl;
  final String body;
  final DateTime? publishedAt;
  final bool draft;
  final bool prerelease;
}

/// Contacts the `prit-007/nook` GitHub releases feed to find the newest
/// published version. Pure Dart + [http.Client] so it works on every platform
/// and is trivial to fake in tests.
class UpdateChecker {
  UpdateChecker({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? 'https://api.github.com';

  static const defaultOwner = 'prit-007';
  static const defaultRepo = 'nook';

  final http.Client _client;
  final String _baseUrl;

  /// Fetches the most recent non-draft release. Returns `null` when the repo
  /// has no releases yet. Throws [UpdateCheckException] on transport or parse
  /// failures.
  Future<GithubRelease?> fetchLatestRelease({
    String owner = defaultOwner,
    String repo = defaultRepo,
  }) async {
    final uri = Uri.parse('$_baseUrl/repos/$owner/$repo/releases?per_page=10');
    final http.Response response;
    try {
      response = await _client.get(uri, headers: const {
        'Accept': 'application/vnd.github+json'
      }).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const UpdateCheckException('Update check timed out.');
    } on Exception catch (e) {
      throw UpdateCheckException('Could not reach the update server: $e');
    }

    if (response.statusCode != 200) {
      throw UpdateCheckException(
        'The update server responded with ${response.statusCode}.',
      );
    }

    final List<dynamic> raw;
    try {
      raw = jsonDecode(response.body) as List<dynamic>;
    } on FormatException {
      throw const UpdateCheckException('Malformed update response.');
    }

    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      final draft = entry['draft'] == true;
      if (draft) continue;
      final prerelease = entry['prerelease'] == true;
      if (prerelease) continue;
      return GithubRelease(
        tagName: entry['tag_name'] as String? ?? '',
        name: entry['name'] as String? ?? '',
        htmlUrl: entry['html_url'] as String? ?? '',
        body: entry['body'] as String? ?? '',
        publishedAt: DateTime.tryParse(entry['published_at'] as String? ?? ''),
        draft: draft,
        prerelease: entry['prerelease'] == true,
      );
    }
    return null;
  }
}
